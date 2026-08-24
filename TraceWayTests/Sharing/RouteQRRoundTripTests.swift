//
//  RouteQRRoundTripTests.swift
//  TraceWayTests
//

import CoreImage
import UIKit
import XCTest
@testable import TraceWay

final class RouteQRRoundTripTests: XCTestCase {
    func testCompactRoundTripPreservesMetadataAndCoordinates() throws {
        let original = RouteQRTestFixtures.makeRoute(pointCount: 250, style: .narrowParallel)
        let encoder = RouteQREncoder(strategy: .compactMicrodegreeDeltas, enforceSingleQRCapacity: false)
        let payload = try encoder.encode(original)
        XCTAssertTrue(payload.hasPrefix("TW1:"))

        let decoded = try RouteQRDecoder().decode(payload)
        assertRoundTrip(original: original, decoded: decoded, maxMeters: 0.25)
    }

    func testFullJSONRoundTrip() throws {
        let original = RouteQRTestFixtures.makeRoute(pointCount: 80, style: .curved)
        let encoder = RouteQREncoder(strategy: .fullJSON, enforceSingleQRCapacity: false)
        let payload = try encoder.encode(original)
        let decoded = try RouteQRDecoder().decode(payload)
        assertRoundTrip(original: original, decoded: decoded, maxMeters: 0.001)
    }

    func testStraightCurvedTurnsUrbanStyles() throws {
        let styles: [RouteQRTestFixtures.TrackStyle] = [
            .straight, .curved, .frequentTurns, .denseUrban, .longHighway
        ]
        let encoder = RouteQREncoder(strategy: .compactMicrodegreeDeltas, enforceSingleQRCapacity: false)
        for style in styles {
            let original = RouteQRTestFixtures.makeRoute(pointCount: 120, style: style)
            let decoded = try RouteQRDecoder().decode(try encoder.encode(original))
            assertRoundTrip(original: original, decoded: decoded, maxMeters: 0.25)
        }
    }

    func testUnsupportedVersionIsRejected() throws {
        let route = RouteQRTestFixtures.makeRoute(pointCount: 20, style: .straight)
        let wire = try RouteQRWireCodec.makeCompactWire(from: route)
        let bad = RouteQRCompactWire(
            v: 99,
            id: wire.id,
            n: wire.n,
            c: wire.c,
            s: wire.s,
            e: wire.e,
            d: wire.d,
            u: wire.u,
            q: wire.q,
            lat0: wire.lat0,
            lon0: wire.lon0,
            t0: wire.t0,
            pts: wire.pts,
            altCm: wire.altCm,
            accCm: wire.accCm
        )
        let json = try JSONEncoder().encode(bad)
        let compressed = try RouteQRCompression.compressLZFSE(json)
        let payload = RouteQRWireCodec.payloadPrefix + RouteQREncoder.urlSafeBase64(compressed)

        XCTAssertThrowsError(try RouteQRDecoder().decode(payload)) { error in
            guard case RouteQRDecodingError.unsupportedVersion(99) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testUnrelatedQRPayloadRejected() {
        XCTAssertThrowsError(try RouteQRDecoder().decode("https://example.com")) { error in
            XCTAssertEqual(error as? RouteQRDecodingError, .invalidFormat)
        }
    }

    func testEmptyRouteEncodingFails() {
        let empty = TraceWaySharedRoute(
            routeName: "Empty",
            createdAt: .now,
            startedAt: .now,
            endedAt: .now,
            distanceMeters: 0,
            durationSeconds: 0,
            points: []
        )
        XCTAssertThrowsError(
            try RouteQREncoder(enforceSingleQRCapacity: false).encode(empty)
        )
    }

    func testQRImageGenerationAndVisionDecodeRoundTrip() throws {
        let original = RouteQRTestFixtures.makeRoute(pointCount: 150, style: .denseUrban)
        let encoder = RouteQREncoder(strategy: .compactMicrodegreeDeltas, enforceSingleQRCapacity: true)
        let payload = try encoder.encode(original)

        let image = try RouteQRImageRenderer(correctionLevel: .q, dimension: 800).makeImage(payload: payload)
        XCTAssertGreaterThan(image.size.width, 0)

        let scanned = try scanQRPayload(from: image)
        let decoded = try RouteQRDecoder().decode(scanned)
        assertRoundTrip(original: original, decoded: decoded, maxMeters: 0.25)
    }

    func testMicrodegreePrecisionIsSubMeter() {
        // Documented quantum ~0.11 m at equator.
        XCTAssertEqual(
            RouteQRCoordinatePrecision.approximateMetersAtEquator,
            0.11132,
            accuracy: 0.001
        )
    }

    private func assertRoundTrip(
        original: TraceWaySharedRoute,
        decoded: TraceWaySharedRoute,
        maxMeters: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(decoded.version, original.version, file: file, line: line)
        XCTAssertEqual(decoded.shareID, original.shareID, file: file, line: line)
        XCTAssertEqual(decoded.routeName, original.routeName, file: file, line: line)
        XCTAssertEqual(decoded.points.count, original.points.count, file: file, line: line)
        XCTAssertEqual(decoded.distanceMeters, original.distanceMeters, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(decoded.durationSeconds, original.durationSeconds, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(decoded.quality, original.quality, file: file, line: line)

        let delta = RouteQRTestFixtures.maxCoordinateDeltaMeters(original: original, decoded: decoded)
        XCTAssertLessThanOrEqual(delta, maxMeters, "Max coordinate error \(delta) m", file: file, line: line)

        for (lhs, rhs) in zip(original.points, decoded.points) {
            if let lt = lhs.timestamp, let rt = rhs.timestamp {
                XCTAssertEqual(lt.timeIntervalSince1970, rt.timeIntervalSince1970, accuracy: 1.0, file: file, line: line)
            }
            if let la = lhs.altitude, let ra = rhs.altitude {
                XCTAssertEqual(la, ra, accuracy: 0.02, file: file, line: line)
            }
            if let lh = lhs.horizontalAccuracy, let rh = rhs.horizontalAccuracy {
                XCTAssertEqual(lh, rh, accuracy: 0.02, file: file, line: line)
            }
        }
    }

    private func scanQRPayload(from image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            throw RouteQRImageError.generationFailed
        }
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: nil)
        guard let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: context,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ) else {
            throw RouteQRDecodingError.invalidPayload
        }
        let features = detector.features(in: ciImage)
        let payload = features
            .compactMap { $0 as? CIQRCodeFeature }
            .compactMap(\.messageString)
            .first
        guard let payload else {
            throw RouteQRDecodingError.invalidPayload
        }
        return payload
    }
}
