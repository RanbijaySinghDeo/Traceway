//
//  RouteReceivedView.swift
//  TraceWay
//

import SwiftUI

struct RouteReceivedView: View {
    let route: Route
    var isDuplicate: Bool = false
    let onOpenRoute: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            Image(systemName: isDuplicate ? "info.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(isDuplicate ? TraceWayTheme.accent : TraceWayTheme.accent)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(isDuplicate ? "Route Already Received" : "Route Received")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(TraceWayTheme.textPrimary)

                Text(route.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TraceWayTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(
                    "\(TraceWayFormatters.distance(route.distanceMeters)) · \(TraceWayFormatters.duration(route.durationSeconds))"
                )
                .font(.subheadline)
                .foregroundStyle(TraceWayTheme.accent)

                Text(
                    isDuplicate
                        ? "This route is already saved in your Received routes."
                        : "Saved to Received Routes · \(route.orderedPoints.count) points"
                )
                .font(.footnote)
                .foregroundStyle(TraceWayTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button("Open Route", action: onOpenRoute)
                    .buttonStyle(TraceWayPrimaryButtonStyle())
                    .accessibilityLabel("Open Route")

                Button("Done", action: onDone)
                    .buttonStyle(TraceWaySecondaryButtonStyle())
                    .accessibilityLabel("Done")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .traceWayScreenBackground()
    }
}
