//
//  DistanceCalculatorTests.swift
//  TraceWayTests
//

import CoreLocation
import XCTest
@testable import TraceWay

final class DistanceCalculatorTests: XCTestCase {
    func testZeroMovement() {
        let point = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 28.61, longitude: 77.2),
            timestamp: Date(),
            horizontalAccuracy: 5,
            speed: 0,
            course: 0
        )
        XCTAssertEqual(DistanceCalculator.cumulativeDistance(of: [point]), 0)
        XCTAssertEqual(DistanceCalculator.cumulativeDistance(of: []), 0)
    }

    func testKnownCoordinates() {
        // ~111.2 m per 0.001° latitude near equator approximation; Delhi is close enough for order-of-magnitude.
        let a = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 28.6000, longitude: 77.2000),
            timestamp: Date(),
            horizontalAccuracy: 5,
            speed: 1,
            course: 0
        )
        let b = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 28.6010, longitude: 77.2000),
            timestamp: Date().addingTimeInterval(10),
            horizontalAccuracy: 5,
            speed: 1,
            course: 0
        )

        let distance = DistanceCalculator.distance(from: a, to: b)
        XCTAssertEqual(distance, 111, accuracy: 5)
    }

    func testCumulativeMultiplePoints() {
        let points = [
            LocationPoint(
                coordinate: CLLocationCoordinate2D(latitude: 28.6000, longitude: 77.2000),
                timestamp: Date(),
                horizontalAccuracy: 5,
                speed: 1,
                course: 0
            ),
            LocationPoint(
                coordinate: CLLocationCoordinate2D(latitude: 28.6010, longitude: 77.2000),
                timestamp: Date().addingTimeInterval(10),
                horizontalAccuracy: 5,
                speed: 1,
                course: 0
            ),
            LocationPoint(
                coordinate: CLLocationCoordinate2D(latitude: 28.6020, longitude: 77.2000),
                timestamp: Date().addingTimeInterval(20),
                horizontalAccuracy: 5,
                speed: 1,
                course: 0
            )
        ]

        let total = DistanceCalculator.cumulativeDistance(of: points)
        XCTAssertEqual(total, 222, accuracy: 10)
    }
}
