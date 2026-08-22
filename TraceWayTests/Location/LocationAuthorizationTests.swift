//
//  LocationAuthorizationTests.swift
//  TraceWayTests
//

import CoreLocation
import XCTest
@testable import TraceWay

final class LocationAuthorizationTests: XCTestCase {
    func testNotDetermined() {
        let state = LocationAuthorizationState.resolve(
            status: .notDetermined,
            accuracy: .fullAccuracy
        )
        XCTAssertEqual(state, .notDetermined)
        XCTAssertFalse(state.canRecordRoute)
    }

    func testWhenInUseWithPreciseAllowsRecording() {
        let state = LocationAuthorizationState.resolve(
            status: .authorizedWhenInUse,
            accuracy: .fullAccuracy
        )
        XCTAssertEqual(state, .authorizedWhenInUse)
        XCTAssertTrue(state.canRecordRoute)
        XCTAssertFalse(state.canRecordInBackground)
    }

    func testAlwaysWithPreciseAllowsBackground() {
        let state = LocationAuthorizationState.resolve(
            status: .authorizedAlways,
            accuracy: .fullAccuracy
        )
        XCTAssertEqual(state, .authorizedAlways)
        XCTAssertTrue(state.canRecordInBackground)
    }

    func testReducedAccuracyMapsToPreciseDisabled() {
        let state = LocationAuthorizationState.resolve(
            status: .authorizedWhenInUse,
            accuracy: .reducedAccuracy
        )
        XCTAssertEqual(state, .preciseLocationDisabled)
        XCTAssertFalse(state.canRecordRoute)
    }

    func testDeniedAndRestricted() {
        XCTAssertEqual(
            LocationAuthorizationState.resolve(
                status: .denied,
                accuracy: .fullAccuracy
            ),
            .denied
        )
        XCTAssertEqual(
            LocationAuthorizationState.resolve(
                status: .restricted,
                accuracy: .fullAccuracy
            ),
            .restricted
        )
    }
}
