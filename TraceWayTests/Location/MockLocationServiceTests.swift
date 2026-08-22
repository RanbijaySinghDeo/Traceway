//
//  MockLocationServiceTests.swift
//  TraceWayTests
//

import CoreLocation
import XCTest
@testable import TraceWay

@MainActor
final class MockLocationServiceTests: XCTestCase {
    func testStartStopTrackingLifecycle() {
        let service = MockLocationService(authorizationState: .authorizedAlways)

        XCTAssertFalse(service.isUpdating)
        service.startUpdating(with: .recording)
        XCTAssertTrue(service.isUpdating)
        XCTAssertEqual(service.startConfigurations.last, .recording)

        service.stopUpdating()
        XCTAssertFalse(service.isUpdating)
        XCTAssertEqual(service.stopCount, 1)
    }

    func testRecordingConfigurationUsesNavigationAccuracy() {
        let config = LocationTrackingConfiguration.recording
        XCTAssertEqual(config.desiredAccuracy, kCLLocationAccuracyBestForNavigation)
        XCTAssertTrue(config.allowsBackgroundUpdates)
        XCTAssertFalse(config.pausesLocationUpdatesAutomatically)
        XCTAssertEqual(config.distanceFilter, kCLDistanceFilterNone)
    }

    func testPreviewConfigurationDoesNotAllowBackground() {
        let config = LocationTrackingConfiguration.preview
        XCTAssertFalse(config.allowsBackgroundUpdates)
    }

    func testEmitLocationUpdatesLatest() async {
        let service = MockLocationService(authorizationState: .authorizedWhenInUse)
        let point = LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: 12.97, longitude: 77.59),
            timestamp: Date(),
            horizontalAccuracy: 6,
            speed: 4,
            course: 180,
            altitude: 900
        )

        service.emitLocation(point)
        XCTAssertEqual(service.latestLocation, point)
    }
}
