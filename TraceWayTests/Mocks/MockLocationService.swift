//
//  MockLocationService.swift
//  TraceWayTests
//

import CoreLocation
import Foundation
@testable import TraceWay

@MainActor
final class MockLocationService: LocationServing {
    private(set) var authorizationState: LocationAuthorizationState
    private(set) var latestLocation: LocationPoint?
    private(set) var isUpdating = false

    private(set) var requestedWhenInUseCount = 0
    private(set) var requestedAlwaysCount = 0
    private(set) var startConfigurations: [LocationTrackingConfiguration] = []
    private(set) var stopCount = 0

    private var authorizationContinuation: AsyncStream<LocationAuthorizationState>.Continuation?
    private var locationContinuation: AsyncStream<LocationPoint>.Continuation?

    lazy var authorizationUpdates: AsyncStream<LocationAuthorizationState> = {
        AsyncStream { continuation in
            self.authorizationContinuation = continuation
            continuation.yield(self.authorizationState)
        }
    }()

    lazy var locationUpdates: AsyncStream<LocationPoint> = {
        AsyncStream { continuation in
            self.locationContinuation = continuation
        }
    }()

    init(authorizationState: LocationAuthorizationState = .notDetermined) {
        self.authorizationState = authorizationState
    }

    func refreshAuthorizationState() {}

    func requestWhenInUseAuthorization() {
        requestedWhenInUseCount += 1
    }

    func requestAlwaysAuthorization() {
        requestedAlwaysCount += 1
    }

    func requestTemporaryFullAccuracyAuthorization() async {}

    func startUpdating(with configuration: LocationTrackingConfiguration) {
        startConfigurations.append(configuration)
        isUpdating = true
    }

    func stopUpdating() {
        stopCount += 1
        isUpdating = false
    }

    func emitAuthorization(_ state: LocationAuthorizationState) {
        authorizationState = state
        authorizationContinuation?.yield(state)
    }

    func emitLocation(_ point: LocationPoint) {
        latestLocation = point
        locationContinuation?.yield(point)
    }
}
