//
//  LocationService.swift
//  TraceWay
//

import CoreLocation
import Foundation

/// Abstraction over Core Location for DI and unit tests.
@MainActor
protocol LocationServing: AnyObject {
    var authorizationState: LocationAuthorizationState { get }
    var latestLocation: LocationPoint? { get }
    var isUpdating: Bool { get }

    /// Emits whenever authorization or precise-location state changes.
    var authorizationUpdates: AsyncStream<LocationAuthorizationState> { get }

    /// Emits accepted raw location updates while tracking is active.
    var locationUpdates: AsyncStream<LocationPoint> { get }

    func refreshAuthorizationState()
    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func requestTemporaryFullAccuracyAuthorization() async

    func startUpdating(with configuration: LocationTrackingConfiguration)
    func stopUpdating()
}

enum LocationServiceError: Error, LocalizedError, Equatable {
    case permissionDenied
    case preciseLocationRequired
    case locationUnavailable
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Location permission was denied."
        case .preciseLocationRequired:
            "Precise Location is required to record accurate routes."
        case .locationUnavailable:
            "Location is currently unavailable."
        case let .underlying(message):
            message
        }
    }
}
