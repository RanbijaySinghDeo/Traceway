//
//  RouteProcessorTests.swift
//  TraceWayTests
//

import CoreLocation
import XCTest
@testable import TraceWay

final class RouteProcessorTests: XCTestCase {
    private var processor: RouteProcessor!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        processor = RouteProcessor(configuration: .default)
    }

    func testValidPointAccepted() {
        let point = makePoint(lat: 28.61, lon: 77.20, accuracy: 8, timeOffset: 0)
        let result = processor.evaluate(point, now: now)
        guard case .accept = result else {
            return XCTFail("Expected accept, got \(result)")
        }
    }

    func testPoorAccuracyRejected() {
        let point = makePoint(lat: 28.61, lon: 77.20, accuracy: 80, timeOffset: 0)
        XCTAssertEqual(processor.evaluate(point, now: now), .reject(.poorAccuracy))
    }

    func testInvalidAccuracyRejected() {
        let point = makePoint(lat: 28.61, lon: 77.20, accuracy: -1, timeOffset: 0)
        XCTAssertEqual(processor.evaluate(point, now: now), .reject(.invalidAccuracy))
    }

    func testStalePointRejected() {
        let point = makePoint(lat: 28.61, lon: 77.20, accuracy: 8, timeOffset: -30)
        XCTAssertEqual(processor.evaluate(point, now: now), .reject(.stale))
    }

    func testImpossibleGPSJumpRejected() {
        _ = processor.evaluate(makePoint(lat: 28.61, lon: 77.20, accuracy: 5, timeOffset: 0), now: now)
        // ~1 degree latitude ≈ 111 km in 1 second → impossible
        let jump = makePoint(lat: 29.61, lon: 77.20, accuracy: 5, timeOffset: 1)
        XCTAssertEqual(processor.evaluate(jump, now: now.addingTimeInterval(1)), .reject(.impossibleJump))
    }

    func testValidSmallMovementAccepted() {
        _ = processor.evaluate(makePoint(lat: 28.610000, lon: 77.200000, accuracy: 5, timeOffset: 0), now: now)
        let next = makePoint(lat: 28.610020, lon: 77.200000, accuracy: 5, timeOffset: 2)
        let result = processor.evaluate(next, now: now.addingTimeInterval(2))
        guard case .accept = result else {
            return XCTFail("Expected small movement accept, got \(result)")
        }
    }

    func testDuplicatePointRejected() {
        let first = makePoint(lat: 28.61, lon: 77.20, accuracy: 5, timeOffset: 0)
        _ = processor.evaluate(first, now: now)
        let duplicate = makePoint(lat: 28.61, lon: 77.20, accuracy: 5, timeOffset: 1)
        XCTAssertEqual(processor.evaluate(duplicate, now: now.addingTimeInterval(1)), .reject(.duplicate))
    }

    func testInvalidTimestampRewindRejected() {
        _ = processor.evaluate(makePoint(lat: 28.61, lon: 77.20, accuracy: 5, timeOffset: 0), now: now)
        let earlier = makePoint(lat: 28.61005, lon: 77.20, accuracy: 5, timeOffset: -5)
        XCTAssertEqual(processor.evaluate(earlier, now: now), .reject(.invalidTimestamp))
    }

    private func makePoint(
        lat: Double,
        lon: Double,
        accuracy: Double,
        timeOffset: TimeInterval
    ) -> LocationPoint {
        LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            timestamp: now.addingTimeInterval(timeOffset),
            horizontalAccuracy: accuracy,
            speed: 5,
            course: 90,
            altitude: 200
        )
    }
}
