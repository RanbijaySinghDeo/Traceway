//
//  LocationPermissionView.swift
//  TraceWay
//

import SwiftUI

struct LocationPermissionView: View {
    let state: LocationAuthorizationState
    let onRequestAccess: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(TraceWayTheme.textPrimary)
                .labelStyle(.titleAndIcon)
                .symbolRenderingMode(.hierarchical)
                .tint(TraceWayTheme.accent)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(TraceWayTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if state == .notDetermined {
                    Button("Allow Location Access", action: onRequestAccess)
                        .buttonStyle(TraceWayPrimaryButtonStyle())
                } else if needsSettings {
                    Button("Open Settings", action: onOpenSettings)
                        .buttonStyle(TraceWayPrimaryButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .traceWayCard()
    }

    private var needsSettings: Bool {
        switch state {
        case .denied, .restricted, .preciseLocationDisabled, .unavailable:
            true
        case .notDetermined, .authorizedWhenInUse, .authorizedAlways:
            false
        }
    }

    private var title: String {
        switch state {
        case .notDetermined:
            "Location required"
        case .denied, .restricted:
            "Location access needed"
        case .preciseLocationDisabled:
            "Precise Location needed"
        case .unavailable:
            "Location unavailable"
        case .authorizedWhenInUse, .authorizedAlways:
            "Location ready"
        }
    }

    private var icon: String {
        switch state {
        case .preciseLocationDisabled:
            "scope"
        case .unavailable:
            "location.slash"
        default:
            "location"
        }
    }

    private var message: String {
        if state == .notDetermined {
            return "TraceWay records the exact path you travel. Location is used only on this device while you record a route."
        }
        let guidance = state.settingsGuidanceMessage
        return guidance.isEmpty
            ? "TraceWay needs location permission to record your route."
            : guidance
    }
}
