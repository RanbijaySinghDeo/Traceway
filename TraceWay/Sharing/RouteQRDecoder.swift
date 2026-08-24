//
//  RouteQRDecoder.swift
//  TraceWay
//

import Foundation

struct RouteQRDecoder: Sendable {
    /// Maximum points accepted from a QR (defensive against malicious payloads).
    var maximumPointCount: Int = 20_000

    func decode(_ payload: String) throws -> TraceWaySharedRoute {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(RouteQRWireCodec.payloadPrefix) else {
            throw RouteQRDecodingError.invalidFormat
        }

        let encoded = String(trimmed.dropFirst(RouteQRWireCodec.payloadPrefix.count))
        guard !encoded.isEmpty else {
            throw RouteQRDecodingError.invalidPayload
        }

        guard let compressed = Self.decodeURLSafeBase64(encoded) else {
            throw RouteQRDecodingError.corruptedData
        }

        let jsonData: Data
        do {
            jsonData = try RouteQRCompression.decompressLZFSE(compressed)
        } catch {
            throw RouteQRDecodingError.decompressionFailed
        }

        // Prefer compact wire; fall back to full TraceWaySharedRoute JSON.
        if let wire = try? JSONDecoder().decode(RouteQRCompactWire.self, from: jsonData) {
            let route = try RouteQRWireCodec.makeSharedRoute(from: wire)
            try validate(route)
            return route
        }

        if let route = try? RouteQRWireCodec.unixJSONDecoder.decode(TraceWaySharedRoute.self, from: jsonData) {
            guard route.version == TraceWaySharedRoute.currentVersion else {
                throw RouteQRDecodingError.unsupportedVersion(route.version)
            }
            try validate(route)
            return route
        }

        // Unsupported version may still decode as compact with wrong v.
        if let probe = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let version = probe["v"] as? Int,
           version != TraceWaySharedRoute.currentVersion {
            throw RouteQRDecodingError.unsupportedVersion(version)
        }
        if let probe = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let version = probe["version"] as? Int,
           version != TraceWaySharedRoute.currentVersion {
            throw RouteQRDecodingError.unsupportedVersion(version)
        }

        throw RouteQRDecodingError.corruptedData
    }

    func validate(_ route: TraceWaySharedRoute) throws {
        if route.version != TraceWaySharedRoute.currentVersion {
            throw RouteQRDecodingError.unsupportedVersion(route.version)
        }
        let name = route.routeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 200 else {
            throw RouteQRDecodingError.validationFailed("Invalid route name.")
        }
        guard !route.points.isEmpty else {
            throw RouteQRDecodingError.validationFailed("Route has no points.")
        }
        guard route.points.count <= maximumPointCount else {
            throw RouteQRDecodingError.validationFailed("Too many points.")
        }
        guard route.distanceMeters.isFinite, route.distanceMeters >= 0 else {
            throw RouteQRDecodingError.validationFailed("Invalid distance.")
        }
        guard route.durationSeconds.isFinite, route.durationSeconds >= 0 else {
            throw RouteQRDecodingError.validationFailed("Invalid duration.")
        }

        for (index, point) in route.points.enumerated() {
            guard point.latitude.isFinite, point.longitude.isFinite else {
                throw RouteQRDecodingError.validationFailed("Non-finite coordinate at \(index).")
            }
            guard (-90...90).contains(point.latitude) else {
                throw RouteQRDecodingError.validationFailed("Latitude out of range at \(index).")
            }
            guard (-180...180).contains(point.longitude) else {
                throw RouteQRDecodingError.validationFailed("Longitude out of range at \(index).")
            }
            if let altitude = point.altitude, !altitude.isFinite {
                throw RouteQRDecodingError.validationFailed("Invalid altitude at \(index).")
            }
            if let accuracy = point.horizontalAccuracy, (!accuracy.isFinite || accuracy < -1) {
                throw RouteQRDecodingError.validationFailed("Invalid accuracy at \(index).")
            }
        }
    }

    static func decodeURLSafeBase64(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}
