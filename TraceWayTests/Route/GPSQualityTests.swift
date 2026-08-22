//
//  GPSQualityTests.swift
//  TraceWayTests
//

import XCTest
@testable import TraceWay

final class GPSQualityTests: XCTestCase {
    private let thresholds = GPSQualityThresholds.default

    func testExcellentFairPoorThresholds() {
        XCTAssertEqual(GPSQuality(horizontalAccuracyMeters: 8, thresholds: thresholds), .excellent)
        XCTAssertEqual(GPSQuality(horizontalAccuracyMeters: 10, thresholds: thresholds), .excellent)
        XCTAssertEqual(GPSQuality(horizontalAccuracyMeters: 18, thresholds: thresholds), .fair)
        XCTAssertEqual(GPSQuality(horizontalAccuracyMeters: 25, thresholds: thresholds), .fair)
        XCTAssertEqual(GPSQuality(horizontalAccuracyMeters: 40, thresholds: thresholds), .poor)
    }

    func testNegativeAccuracyIsUnknown() {
        XCTAssertEqual(GPSQuality(horizontalAccuracyMeters: -1, thresholds: thresholds), .unknown)
    }
}
