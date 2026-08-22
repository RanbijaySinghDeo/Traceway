//
//  LocationAuthorization.swift
//  TraceWay
//

import CoreLocation
import Foundation

/// App-facing authorization state, including precise-location requirements.
enum LocationAuthorizationState: Sendable, Equatable {
    case notDetermined
    case authorizedWhenInUse
    case authorizedAlways
    case denied
    case restricted
    /// Location granted but system Precise Location is off (reduced accuracy).
    case preciseLocationDisabled
    case unavailable

    /// Enough for showing the user on the map before recording.
    var canShowUserLocation: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            true
        case .notDetermined, .denied, .restricted, .preciseLocationDisabled, .unavailable:
            false
        }
    }

    /// Background + lock-screen recording requires Always + precise.
    var canRecordInBackground: Bool {
        self == .authorizedAlways
    }

    /// Foreground recording is allowed with When In Use or Always (precise).
    var canRecordRoute: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            true
        case .notDetermined, .denied, .restricted, .preciseLocationDisabled, .unavailable:
            false
        }
    }

    var settingsGuidanceMessage: String {
        switch self {
        case .denied:
            "Location access is off. Open Settings → Privacy & Security → Location Services, enable it if needed, then open TraceWay → Location and choose While Using the App or Always with Precise Location on."
        case .restricted:
            "Location access is restricted on this device (for example by Screen Time or a device profile)."
        case .preciseLocationDisabled:
            "Precise Location is off. Open Settings → TraceWay → Location and turn on Precise Location so TraceWay can record narrow roads accurately."
        case .unavailable:
            "Location is currently unavailable. Try again when GPS signal is available."
        case .notDetermined, .authorizedWhenInUse, .authorizedAlways:
            ""
        }
    }
}

extension LocationAuthorizationState {
    /// Resolves app state from the manager instance properties only.
    /// Avoid `CLLocationManager.locationServicesEnabled()` on the main thread —
    /// it can block the UI; rely on `locationManagerDidChangeAuthorization:` instead.
    static func resolve(
        status: CLAuthorizationStatus,
        accuracy: CLAccuracyAuthorization
    ) -> LocationAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            // Global Location Services off also surfaces as `.denied` for the app.
            return .denied
        case .restricted:
            return .restricted
        case .authorizedWhenInUse, .authorizedAlways:
            if accuracy == .reducedAccuracy {
                return .preciseLocationDisabled
            }
            return status == .authorizedAlways ? .authorizedAlways : .authorizedWhenInUse
        @unknown default:
            return .unavailable
        }
    }
}
