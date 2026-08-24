//
//  RouteQRCapacityTests.swift
//  TraceWayTests
//

import XCTest
@testable import TraceWay

final class RouteQRCapacityTests: XCTestCase {
    /// Bulk size sweep — no Core Image (avoids simulator SEGV on large/near-limit payloads).
    func testCapacityComparisonAcrossPointCounts() throws {
        let pointCounts = [100, 500, 1_000, 2_000, 5_000]
        let levels: [RouteQRErrorCorrectionLevel] = [.q, .m, .l]

        var report: [String] = []
        report.append("TraceWay QR Capacity Experiment")
        report.append(
            "Compact quantum: \(RouteQRCoordinatePrecision.degreesQuantum)° ≈ \(String(format: "%.3f", RouteQRCoordinatePrecision.approximateMetersAtEquator)) m"
        )
        report.append("Optional fields: timestamp + altitude + horizontalAccuracy included")
        report.append("")

        for level in levels {
            report.append("=== Error correction \(level.rawValue) (V40 max \(level.maxByteCapacityVersion40) bytes) ===")
            report.append("Points\tStrategy\tJSON\tLZFSE\tBase64\tPayload\tQRVer\tFitTable\tRoundTrip")

            for count in pointCounts {
                let route = RouteQRTestFixtures.makeRoute(pointCount: count, style: .denseUrban)
                for strategy in RouteQRCoordinateStrategy.allCases {
                    let encoder = RouteQREncoder(
                        strategy: strategy,
                        enforceSingleQRCapacity: false,
                        errorCorrectionLevel: level
                    )
                    let metrics = try encoder.measure(route, attemptImageGeneration: false)
                    let versionText = metrics.estimatedMinimumQRVersion.map(String.init) ?? "N/A"
                    let fit = metrics.fitsSingleQR ? "YES" : "NO"
                    let rt = metrics.roundTripSucceeded ? "YES" : "NO"
                    report.append(
                        "\(metrics.pointCount)\t\(strategy == .fullJSON ? "full" : "compact")\t\(metrics.jsonBytes)\t\(metrics.compressedBytes)\t\(metrics.base64Bytes)\t\(metrics.payloadBytes)\t\(versionText)\t\(fit)\t\(rt)"
                    )
                }
            }
            report.append("")
        }

        // Coordinates + timestamps only (no alt/acc) — closer to minimal useful share payload.
        report.append("=== Compact, EC=Q, coordinates+timestamps only (no alt/acc) ===")
        for count in pointCounts {
            let route = RouteQRTestFixtures.makeRoute(
                pointCount: count,
                style: .denseUrban,
                includeOptionalFields: false
            )
            // Re-add timestamps only for a realistic minimal track.
            let withTime = TraceWaySharedRoute(
                version: route.version,
                shareID: route.shareID,
                routeName: route.routeName,
                createdAt: route.createdAt,
                startedAt: route.startedAt,
                endedAt: route.endedAt,
                distanceMeters: route.distanceMeters,
                durationSeconds: route.durationSeconds,
                quality: route.quality,
                points: zip(route.points.indices, route.points).map { index, point in
                    TraceWaySharedRoutePoint(
                        latitude: point.latitude,
                        longitude: point.longitude,
                        timestamp: route.startedAt.addingTimeInterval(TimeInterval(index * 2))
                    )
                }
            )
            let metrics = try RouteQREncoder(
                strategy: .compactMicrodegreeDeltas,
                enforceSingleQRCapacity: false,
                errorCorrectionLevel: .q
            ).measure(withTime, attemptImageGeneration: false)
            let versionText = metrics.estimatedMinimumQRVersion.map(String.init) ?? "N/A"
            report.append(
                "\(count)\tcompact-min\tJSON=\(metrics.jsonBytes)\tLZFSE=\(metrics.compressedBytes)\tPayload=\(metrics.payloadBytes)\tVer=\(versionText)\tFit=\(metrics.fitsSingleQR ? "YES" : "NO")"
            )
        }

        let text = report.joined(separator: "\n")
        print("\n\(text)\n")

        let small = RouteQRTestFixtures.makeRoute(pointCount: 100, style: .denseUrban)
        let full = try RouteQREncoder(
            strategy: .fullJSON,
            enforceSingleQRCapacity: false,
            errorCorrectionLevel: .q
        ).measure(small, attemptImageGeneration: false)
        let compact = try RouteQREncoder(
            strategy: .compactMicrodegreeDeltas,
            enforceSingleQRCapacity: false,
            errorCorrectionLevel: .q
        ).measure(small, attemptImageGeneration: false)
        XCTAssertLessThan(compact.payloadBytes, full.payloadBytes)
        XCTAssertTrue(compact.fitsSingleQR)
        XCTAssertTrue(compact.roundTripSucceeded)
    }

    func testEncodeThrowsRouteTooLargeWhenEnforced() throws {
        let huge = RouteQRTestFixtures.makeRoute(pointCount: 5_000, style: .longHighway)
        let encoder = RouteQREncoder(
            strategy: .fullJSON,
            enforceSingleQRCapacity: true,
            errorCorrectionLevel: .h
        )
        XCTAssertThrowsError(try encoder.encode(huge)) { error in
            guard case RouteQREncodingError.routeTooLarge = error else {
                if error is RouteQRImageError { return }
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testLargeCompactRoundTripSurvivesHighCompressionRatio() throws {
        // Dense tracks LZFSE-compress ~200×; decompression must allocate enough scratch space.
        let original = RouteQRTestFixtures.makeRoute(pointCount: 5_000, style: .denseUrban)
        let encoder = RouteQREncoder(
            strategy: .compactMicrodegreeDeltas,
            enforceSingleQRCapacity: false,
            errorCorrectionLevel: .q
        )
        let payload = try encoder.encode(original)
        let decoded = try RouteQRDecoder().decode(payload)
        XCTAssertEqual(decoded.points.count, original.points.count)
        XCTAssertEqual(decoded.shareID, original.shareID)
    }

    func testRecommendedPracticalLimitSnapshot() throws {
        let encoder = RouteQREncoder(
            strategy: .compactMicrodegreeDeltas,
            enforceSingleQRCapacity: false,
            errorCorrectionLevel: .q
        )

        let counts = [100, 500, 1_000, 2_000, 5_000]
        var lines: [String] = [
            "Recommended-limit snapshot (compact + LZFSE + URL-safe Base64 + TW1:, EC=Q):"
        ]

        for count in counts {
            let route = RouteQRTestFixtures.makeRoute(pointCount: count, style: .narrowParallel)
            // Size first without CI; then verify CI only when table says it fits.
            let sized = try encoder.measure(route, attemptImageGeneration: false)
            var generationOK = false
            if sized.fitsSingleQR {
                let verified = try encoder.measure(route, attemptImageGeneration: true)
                generationOK = verified.generationSucceeded
            }
            lines.append(
                "\(count) → payload \(sized.payloadBytes)B ver \(sized.estimatedMinimumQRVersion.map(String.init) ?? "N/A") fitTable=\(sized.fitsSingleQR) gen=\(generationOK)"
            )
            if count <= 500 {
                XCTAssertTrue(sized.fitsSingleQR, "Expected \(count) points to fit at EC=Q")
                XCTAssertTrue(generationOK, "Expected CI generation for \(count) points")
            }
        }

        print(lines.joined(separator: "\n"))
    }
}
