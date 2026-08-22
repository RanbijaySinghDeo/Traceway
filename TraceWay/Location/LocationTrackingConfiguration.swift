//
//  LocationTrackingConfiguration.swift
//  TraceWay
//

import CoreLocation
import Foundation

/// Core Location settings for a tracking session.
/// High accuracy is intentional while recording; idle tracking should not use this.
struct LocationTrackingConfiguration: Sendable, Equatable {
    var desiredAccuracy: CLLocationAccuracy
    var distanceFilter: CLLocationDistance
    var allowsBackgroundUpdates: Bool
    var pausesLocationUpdatesAutomatically: Bool
    var activityType: CLActivityType
    var showsBackgroundLocationIndicator: Bool

    /// High-fidelity recording for narrow / poorly mapped roads.
    static let recording = LocationTrackingConfiguration(
        desiredAccuracy: kCLLocationAccuracyBestForNavigation,
        // Do not thin updates aggressively — small turns on colony roads matter.
        distanceFilter: kCLDistanceFilterNone,
        allowsBackgroundUpdates: true,
        pausesLocationUpdatesAutomatically: false,
        activityType: .otherNavigation,
        showsBackgroundLocationIndicator: true
    )

    /// Brief foreground updates to center the map before recording starts.
    static let preview = LocationTrackingConfiguration(
        desiredAccuracy: kCLLocationAccuracyBest,
        distanceFilter: 10,
        allowsBackgroundUpdates: false,
        pausesLocationUpdatesAutomatically: true,
        activityType: .other,
        showsBackgroundLocationIndicator: false
    )
}
