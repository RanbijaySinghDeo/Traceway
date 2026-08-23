//
//  RouteQRPathSimplifierTests.swift
//  TraceWayTests
//

import XCTest
@testable import TraceWay

final class RouteQRPathSimplifierTests: XCTestCase {
    func testShortRouteFitsWithoutSimplification() throws {
        let shared = RouteQRTestFixtures.makeRoute(pointCount: 250, style: .narrowParallel)
        let encoder = RouteQREncoder(
            strategy: .compactMicrodegreeDeltas,
            enforceSingleQRCapacity: true,
            errorCorrectionLevel: .q
        )
        // Short routes encode as-is — ViewModel will not call the simplifier.
        let payload = try encoder.encode(shared)
        XCTAssertTrue(payload.hasPrefix("TW1:"))
        XCTAssertLessThanOrEqual(payload.utf8.count, RouteQRErrorCorrectionLevel.q.maxByteCapacityVersion40)
    }

    func testLongRouteIsReducedToBudget() {
        let shared = RouteQRTestFixtures.makeRoute(pointCount: 4_000, style: .longHighway)
        let result = RouteQRPathSimplifier.simplifyForQR(shared, maxPoints: 1_000)

        XCTAssertEqual(result.originalPointCount, 4_000)
        XCTAssertLessThanOrEqual(result.simplifiedPointCount, 1_000)
        XCTAssertTrue(result.didSimplify)
        XCTAssertEqual(result.route.points.first?.latitude, shared.points.first?.latitude)
        XCTAssertEqual(result.route.points.last?.longitude, shared.points.last?.longitude)
        XCTAssertEqual(result.route.shareID, shared.shareID)
        XCTAssertTrue(result.route.points.allSatisfy { $0.altitude == nil && $0.horizontalAccuracy == nil })
    }

    func testSimplifiedLongRouteFitsSingleQR() throws {
        let shared = RouteQRTestFixtures.makeRoute(pointCount: 5_000, style: .narrowParallel)
        let simplified = RouteQRPathSimplifier.simplifyForQR(shared, maxPoints: 1_000).route
        let encoder = RouteQREncoder(
            strategy: .compactMicrodegreeDeltas,
            enforceSingleQRCapacity: true,
            errorCorrectionLevel: .q
        )
        XCTAssertNoThrow(try encoder.encode(simplified))
    }

    func testPreservesEndpointOrder() {
        let shared = RouteQRTestFixtures.makeRoute(pointCount: 3_000, style: .frequentTurns)
        let result = RouteQRPathSimplifier.simplifyForQR(shared, maxPoints: 800)
        XCTAssertEqual(result.route.points.first?.latitude, shared.points.first?.latitude)
        XCTAssertEqual(result.route.points.first?.longitude, shared.points.first?.longitude)
        XCTAssertEqual(result.route.points.last?.latitude, shared.points.last?.latitude)
        XCTAssertEqual(result.route.points.last?.longitude, shared.points.last?.longitude)
    }
}
