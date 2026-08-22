//
//  LocationManager.swift
//  TraceWay
//

import CoreLocation
import Foundation

/// Core Location-backed `LocationServing` implementation.
/// Location hardware runs only while `startUpdating` is active.
@MainActor
final class LocationManager: NSObject, LocationServing {
    private let manager: CLLocationManager

    private(set) var authorizationState: LocationAuthorizationState = .notDetermined
    private(set) var latestLocation: LocationPoint?
    private(set) var isUpdating = false

    private var authorizationContinuations: [UUID: AsyncStream<LocationAuthorizationState>.Continuation] = [:]
    private var locationContinuations: [UUID: AsyncStream<LocationPoint>.Continuation] = [:]

    var authorizationUpdates: AsyncStream<LocationAuthorizationState> {
        AsyncStream { continuation in
            let id = UUID()
            self.authorizationContinuations[id] = continuation
            continuation.yield(self.authorizationState)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.authorizationContinuations[id] = nil
                }
            }
        }
    }

    var locationUpdates: AsyncStream<LocationPoint> {
        AsyncStream { continuation in
            let id = UUID()
            self.locationContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.locationContinuations[id] = nil
                }
            }
        }
    }

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        self.manager.delegate = self
        // Seed from instance status only. Do not call `locationServicesEnabled()` here —
        // it can stall the main thread. Further updates arrive via
        // `locationManagerDidChangeAuthorization:`.
        refreshAuthorizationState()
    }

    func refreshAuthorizationState() {
        publishAuthorization(
            LocationAuthorizationState.resolve(
                status: manager.authorizationStatus,
                accuracy: manager.accuracyAuthorization
            )
        )
    }

    func requestWhenInUseAuthorization() {
        // Only prompt when undetermined; otherwise wait on the authorization callback.
        guard manager.authorizationStatus == .notDetermined else {
            refreshAuthorizationState()
            return
        }
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .notDetermined else {
            refreshAuthorizationState()
            return
        }
        manager.requestAlwaysAuthorization()
    }

    func requestTemporaryFullAccuracyAuthorization() async {
        guard manager.accuracyAuthorization == .reducedAccuracy else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "TraceWayRecording") { _ in
                Task { @MainActor in
                    self.refreshAuthorizationState()
                    continuation.resume()
                }
            }
        }
    }

    func startUpdating(with configuration: LocationTrackingConfiguration) {
        apply(configuration)
        manager.startUpdatingLocation()
        isUpdating = true
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isUpdating = false
    }

    private func apply(_ configuration: LocationTrackingConfiguration) {
        manager.desiredAccuracy = configuration.desiredAccuracy
        manager.distanceFilter = configuration.distanceFilter
        manager.activityType = configuration.activityType
        manager.pausesLocationUpdatesAutomatically = configuration.pausesLocationUpdatesAutomatically
        // Background updates require the location background mode and appropriate authorization.
        manager.allowsBackgroundLocationUpdates = configuration.allowsBackgroundUpdates
        manager.showsBackgroundLocationIndicator = configuration.showsBackgroundLocationIndicator
    }

    private func publishAuthorization(_ state: LocationAuthorizationState) {
        authorizationState = state
        for continuation in authorizationContinuations.values {
            continuation.yield(state)
        }
    }

    private func publishLocation(_ point: LocationPoint) {
        latestLocation = point
        for continuation in locationContinuations.values {
            continuation.yield(point)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let accuracy = manager.accuracyAuthorization
        let resolved = LocationAuthorizationState.resolve(status: status, accuracy: accuracy)
        Task { @MainActor in
            self.publishAuthorization(resolved)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let point = LocationPoint(location: location)
        Task { @MainActor in
            self.publishLocation(point)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError, clError.code == .denied {
                self.publishAuthorization(.denied)
            }
        }
    }
}
