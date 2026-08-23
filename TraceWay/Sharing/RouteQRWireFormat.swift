//
//  RouteQRWireFormat.swift
//  TraceWay
//

import Foundation

/// Compact QR wire schema (Approach B). Short keys + microdegree deltas.
/// Public API remains `TraceWaySharedRoute` with full Doubles.
struct RouteQRCompactWire: Codable, Sendable {
    let v: Int
    let id: String
    let n: String
    let c: Double
    let s: Double
    let e: Double
    let d: Double
    let u: Double
    let q: String?
    /// Origin latitude in microdegrees (1e-6°).
    let lat0: Int
    /// Origin longitude in microdegrees (1e-6°).
    let lon0: Int
    /// Origin timestamp (unix seconds), if present on first point.
    let t0: Double?
    /// Packed points: [dLat, dLon] or [dLat, dLon, dTimeSeconds] relative to previous.
    let pts: [[Int]]
    /// Optional altitude (cm) and horizontalAccuracy (cm) parallel arrays — omitted when unused.
    let altCm: [Int]?
    let accCm: [Int]?
}

enum RouteQRWireCodec {
    static let payloadPrefix = "TW1:"

    static var isoJSONEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [] // compact, no pretty print
        return encoder
    }

    static var isoJSONDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static var unixJSONEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = []
        return encoder
    }

    static var unixJSONDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    static func toMicrodegrees(_ degrees: Double) -> Int {
        Int((degrees * RouteQRCoordinatePrecision.microdegreesScale).rounded())
    }

    static func fromMicrodegrees(_ value: Int) -> Double {
        Double(value) / RouteQRCoordinatePrecision.microdegreesScale
    }

    static func makeCompactWire(from route: TraceWaySharedRoute) throws -> RouteQRCompactWire {
        guard let first = route.points.first else {
            throw RouteQREncodingError.emptyRoute
        }

        let lat0 = toMicrodegrees(first.latitude)
        let lon0 = toMicrodegrees(first.longitude)
        var prevLat = lat0
        var prevLon = lon0
        var prevTime: Int? = first.timestamp.map { Int($0.timeIntervalSince1970.rounded()) }

        var packed: [[Int]] = []
        var altitudes: [Int] = []
        var accuracies: [Int] = []
        var hasAltitude = false
        var hasAccuracy = false

        for (index, point) in route.points.enumerated() {
            let lat = toMicrodegrees(point.latitude)
            let lon = toMicrodegrees(point.longitude)

            if index == 0 {
                packed.append([0, 0])
            } else {
                var entry = [lat - prevLat, lon - prevLon]
                if let timestamp = point.timestamp {
                    let t = Int(timestamp.timeIntervalSince1970.rounded())
                    let deltaT = t - (prevTime ?? t)
                    entry.append(deltaT)
                    prevTime = t
                }
                packed.append(entry)
            }

            prevLat = lat
            prevLon = lon

            if let altitude = point.altitude, altitude.isFinite {
                hasAltitude = true
                altitudes.append(Int((altitude * 100).rounded()))
            } else {
                altitudes.append(-1)
            }

            if let accuracy = point.horizontalAccuracy, accuracy.isFinite, accuracy >= 0 {
                hasAccuracy = true
                accuracies.append(Int((accuracy * 100).rounded()))
            } else {
                accuracies.append(-1)
            }
        }

        return RouteQRCompactWire(
            v: route.version,
            id: route.shareID.uuidString,
            n: route.routeName,
            c: route.createdAt.timeIntervalSince1970,
            s: route.startedAt.timeIntervalSince1970,
            e: route.endedAt.timeIntervalSince1970,
            d: route.distanceMeters,
            u: route.durationSeconds,
            q: route.quality,
            lat0: lat0,
            lon0: lon0,
            t0: first.timestamp?.timeIntervalSince1970,
            pts: packed,
            altCm: hasAltitude ? altitudes : nil,
            accCm: hasAccuracy ? accuracies : nil
        )
    }

    static func makeSharedRoute(from wire: RouteQRCompactWire) throws -> TraceWaySharedRoute {
        guard wire.v == TraceWaySharedRoute.currentVersion else {
            throw RouteQRDecodingError.unsupportedVersion(wire.v)
        }
        guard let shareID = UUID(uuidString: wire.id) else {
            throw RouteQRDecodingError.validationFailed("Invalid shareID.")
        }
        guard !wire.pts.isEmpty else {
            throw RouteQRDecodingError.validationFailed("Route has no points.")
        }

        var latitude = wire.lat0
        var longitude = wire.lon0
        var time: Int? = wire.t0.map { Int($0.rounded()) }
        var points: [TraceWaySharedRoutePoint] = []

        for (index, entry) in wire.pts.enumerated() {
            guard entry.count >= 2 else {
                throw RouteQRDecodingError.validationFailed("Malformed point at index \(index).")
            }

            if index == 0 {
                latitude = wire.lat0
                longitude = wire.lon0
            } else {
                latitude += entry[0]
                longitude += entry[1]
                if entry.count >= 3, var currentTime = time {
                    currentTime += entry[2]
                    time = currentTime
                }
            }

            let altitude: Double?
            if let altCm = wire.altCm, index < altCm.count, altCm[index] >= 0 {
                altitude = Double(altCm[index]) / 100.0
            } else {
                altitude = nil
            }

            let accuracy: Double?
            if let accCm = wire.accCm, index < accCm.count, accCm[index] >= 0 {
                accuracy = Double(accCm[index]) / 100.0
            } else {
                accuracy = nil
            }

            let timestamp: Date?
            if index == 0 {
                timestamp = wire.t0.map { Date(timeIntervalSince1970: $0) }
            } else {
                timestamp = time.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            }

            points.append(
                TraceWaySharedRoutePoint(
                    latitude: fromMicrodegrees(latitude),
                    longitude: fromMicrodegrees(longitude),
                    timestamp: timestamp,
                    altitude: altitude,
                    horizontalAccuracy: accuracy
                )
            )
        }

        return TraceWaySharedRoute(
            version: wire.v,
            shareID: shareID,
            routeName: wire.n,
            createdAt: Date(timeIntervalSince1970: wire.c),
            startedAt: Date(timeIntervalSince1970: wire.s),
            endedAt: Date(timeIntervalSince1970: wire.e),
            distanceMeters: wire.d,
            durationSeconds: wire.u,
            quality: wire.q,
            points: points
        )
    }
}
