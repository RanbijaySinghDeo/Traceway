//
//  RouteQREncoder.swift
//  TraceWay
//

import Foundation

struct RouteQREncoder: Sendable {
    var strategy: RouteQRCoordinateStrategy
    /// When true, throws if payload cannot fit a Version-40 QR at the target EC level.
    var enforceSingleQRCapacity: Bool
    var errorCorrectionLevel: RouteQRErrorCorrectionLevel

    init(
        strategy: RouteQRCoordinateStrategy = .compactMicrodegreeDeltas,
        enforceSingleQRCapacity: Bool = true,
        errorCorrectionLevel: RouteQRErrorCorrectionLevel = .q
    ) {
        self.strategy = strategy
        self.enforceSingleQRCapacity = enforceSingleQRCapacity
        self.errorCorrectionLevel = errorCorrectionLevel
    }

    /// Encodes a shared route into a TraceWay QR payload string (`TW1:…`).
    func encode(_ route: TraceWaySharedRoute) throws -> String {
        try validateForEncoding(route)

        let jsonData: Data
        switch strategy {
        case .fullJSON:
            jsonData = try RouteQRWireCodec.unixJSONEncoder.encode(route)
        case .compactMicrodegreeDeltas:
            let wire = try RouteQRWireCodec.makeCompactWire(from: route)
            jsonData = try JSONEncoder().encode(wire)
        }

        let compressed = try RouteQRCompression.compressLZFSE(jsonData)
        let payload = RouteQRWireCodec.payloadPrefix + Self.urlSafeBase64(compressed)

        if enforceSingleQRCapacity {
            let maxBytes = errorCorrectionLevel.maxByteCapacityVersion40
            let payloadByteCount = payload.lengthOfBytes(using: .utf8)
            guard payloadByteCount <= maxBytes else {
                throw RouteQREncodingError.routeTooLarge(payloadBytes: payloadByteCount)
            }
            // Do not probe Core Image here — CI can fail for non-capacity reasons and the
            // image renderer already validates generation when drawing the QR.
        }

        return payload
    }

    /// Metrics helper for capacity experiments (does not enforce QR fit).
    /// - Parameter attemptImageGeneration: When false, skips Core Image (safer for bulk size sweeps).
    func measure(_ route: TraceWaySharedRoute, attemptImageGeneration: Bool = true) throws -> RouteQRPayloadMetrics {
        try validateForEncoding(route)

        let jsonData: Data
        switch strategy {
        case .fullJSON:
            jsonData = try RouteQRWireCodec.unixJSONEncoder.encode(route)
        case .compactMicrodegreeDeltas:
            let wire = try RouteQRWireCodec.makeCompactWire(from: route)
            jsonData = try JSONEncoder().encode(wire)
        }

        let compressed = try RouteQRCompression.compressLZFSE(jsonData)
        let base64URL = Self.urlSafeBase64(compressed)
        let payload = RouteQRWireCodec.payloadPrefix + base64URL
        let payloadBytes = payload.lengthOfBytes(using: .utf8)
        let withinTableCapacity = payloadBytes <= errorCorrectionLevel.maxByteCapacityVersion40

        var generationSucceeded = false
        if attemptImageGeneration, withinTableCapacity {
            do {
                _ = try RouteQRImageRenderer(correctionLevel: errorCorrectionLevel)
                    .makeCIImage(payload: payload)
                generationSucceeded = true
            } catch {
                generationSucceeded = false
            }
        }

        var decodeSucceeded = false
        do {
            let decoded = try RouteQRDecoder().decode(payload)
            decodeSucceeded = decoded.shareID == route.shareID && decoded.points.count == route.points.count
        } catch {
            decodeSucceeded = false
        }

        return RouteQRPayloadMetrics(
            pointCount: route.points.count,
            strategy: strategy,
            jsonBytes: jsonData.count,
            compressedBytes: compressed.count,
            base64Bytes: base64URL.count,
            payloadBytes: payloadBytes,
            errorCorrectionLevel: errorCorrectionLevel,
            estimatedMinimumQRVersion: RouteQRCapacityTable.minimumVersion(
                byteCount: payloadBytes,
                level: errorCorrectionLevel
            ),
            fitsSingleQR: withinTableCapacity && (attemptImageGeneration ? generationSucceeded : withinTableCapacity),
            generationSucceeded: generationSucceeded,
            roundTripSucceeded: decodeSucceeded
        )
    }

    static func urlSafeBase64(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func validateForEncoding(_ route: TraceWaySharedRoute) throws {
        guard !route.points.isEmpty else {
            throw RouteQREncodingError.emptyRoute
        }
        guard route.version == TraceWaySharedRoute.currentVersion else {
            throw RouteQREncodingError.encodingFailed
        }
        guard route.routeName.count <= 200 else {
            throw RouteQREncodingError.encodingFailed
        }
        guard route.points.count <= 20_000 else {
            throw RouteQREncodingError.routeTooLarge(payloadBytes: route.points.count)
        }
    }
}

struct RouteQRPayloadMetrics: Sendable, Equatable {
    let pointCount: Int
    let strategy: RouteQRCoordinateStrategy
    let jsonBytes: Int
    let compressedBytes: Int
    let base64Bytes: Int
    let payloadBytes: Int
    let errorCorrectionLevel: RouteQRErrorCorrectionLevel
    let estimatedMinimumQRVersion: Int?
    let fitsSingleQR: Bool
    let generationSucceeded: Bool
    let roundTripSucceeded: Bool
}
