//
//  RouteMapView.swift
//  TraceWay
//

import MapKit
import CoreLocation
import SwiftUI

struct RouteMapView: View {
    var userCoordinate: CLLocationCoordinate2D?
    var routeCoordinates: [CLLocationCoordinate2D]
    var showsUserLocation: Bool
    var followUser: Bool
    var fitToRoute: Bool
    /// Extra bottom padding (points) so fitted routes sit above overlay cards.
    var bottomContentInset: CGFloat = 0
    /// Camera radius when following the user (smaller = more zoomed in).
    var followZoomMeters: CLLocationDistance = 320

    @State private var position: MapCameraPosition = .automatic
    @State private var lastFittedSignature: Int = 0
    @State private var didCenterOnUser = false

    var body: some View {
        Map(position: $position) {
            if showsUserLocation, let userCoordinate {
                Annotation("You", coordinate: userCoordinate, anchor: .center) {
                    ZStack {
                        Circle()
                            .fill(TraceWayTheme.accent.opacity(0.28))
                            .frame(width: 48, height: 48)
                        Circle()
                            .strokeBorder(TraceWayTheme.accent.opacity(0.7), lineWidth: 2)
                            .frame(width: 30, height: 30)
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(TraceWayTheme.textPrimary)
                    }
                }
            } else if showsUserLocation {
                UserAnnotation()
            }

            if routeCoordinates.count >= 2 {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(
                        TraceWayTheme.routeGlow.opacity(0.35),
                        style: StrokeStyle(
                            lineWidth: TraceWayTheme.routeGlowWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(
                        TraceWayTheme.accent,
                        style: StrokeStyle(
                            lineWidth: TraceWayTheme.routeLineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }

            if let start = routeCoordinates.first {
                Annotation("Start", coordinate: start) {
                    mapPin(systemName: "flag.fill", tint: TraceWayTheme.accent)
                }
            }

            if routeCoordinates.count > 1, let end = routeCoordinates.last {
                Annotation("End", coordinate: end) {
                    mapPin(systemName: "flag.checkered", tint: TraceWayTheme.warning)
                }
            }
        }
        .mapStyle(
            .standard(
                elevation: .flat,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        )
        .preferredColorScheme(.dark)
        .colorMultiply(Color(red: 0.72, green: 0.78, blue: 0.76))
        .saturation(0.55)
        .contrast(1.15)
        .brightness(-0.08)
        .background(TraceWayTheme.background)
        .onAppear {
            fitCameraIfNeeded(animated: false, force: true)
            centerOnUserIfNeeded(animated: false)
        }
        .task(id: routeSignature) {
            fitCameraIfNeeded(animated: false, force: true)
            try? await Task.sleep(for: .milliseconds(80))
            fitCameraIfNeeded(animated: true, force: true)
        }
        .task(id: userCoordinateSignature) {
            // Location often arrives after first frame — zoom to user as soon as we have a fix.
            guard followUser, !fitToRoute else { return }
            centerOnUserIfNeeded(animated: false)
            try? await Task.sleep(for: .milliseconds(100))
            centerOnUserIfNeeded(animated: true)
        }
        .onChange(of: routeSignature) { _, _ in
            fitCameraIfNeeded(animated: true, force: true)
        }
        .onChange(of: userCoordinate?.latitude) { _, _ in
            if followUser, !fitToRoute {
                updateFollowCamera(animated: true)
            }
        }
        .onChange(of: followUser) { _, isFollowing in
            if isFollowing, !fitToRoute {
                didCenterOnUser = false
                centerOnUserIfNeeded(animated: true)
            }
        }
        .onChange(of: fitToRoute) { _, shouldFit in
            if shouldFit {
                fitCameraIfNeeded(animated: true, force: true)
            } else if followUser {
                didCenterOnUser = false
                centerOnUserIfNeeded(animated: true)
            }
        }
    }

    private var userCoordinateSignature: String {
        guard let userCoordinate else { return "nil" }
        return String(format: "%.5f,%.5f-%d", userCoordinate.latitude, userCoordinate.longitude, followUser ? 1 : 0)
    }

    /// Stable signature so we refit when the path itself changes, not only count.
    private var routeSignature: Int {
        var hasher = Hasher()
        hasher.combine(fitToRoute)
        hasher.combine(bottomContentInset)
        hasher.combine(routeCoordinates.count)
        if let first = routeCoordinates.first {
            hasher.combine(first.latitude)
            hasher.combine(first.longitude)
        }
        if let last = routeCoordinates.last {
            hasher.combine(last.latitude)
            hasher.combine(last.longitude)
        }
        return hasher.finalize()
    }

    private func mapPin(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(8)
            .background(TraceWayTheme.surface.opacity(0.92), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func fitCameraIfNeeded(animated: Bool, force: Bool) {
        guard fitToRoute, routeCoordinates.count >= 2 else {
            return
        }

        let signature = routeSignature
        if !force, signature == lastFittedSignature { return }
        lastFittedSignature = signature

        let region = regionFitting(
            routeCoordinates,
            bottomContentInset: bottomContentInset
        )
        withAnimation(animated ? .easeInOut(duration: 0.4) : nil) {
            position = .region(region)
        }
    }

    private func centerOnUserIfNeeded(animated: Bool) {
        guard followUser, !fitToRoute, userCoordinate != nil else { return }
        updateFollowCamera(animated: animated)
        didCenterOnUser = true
    }

    private func updateFollowCamera(animated: Bool) {
        guard let userCoordinate else { return }

        var center = userCoordinate
        // Nudge camera so the user sits above the record controls card.
        if bottomContentInset > 0 {
            let metersSouth = min(120, Double(bottomContentInset) * 0.25)
            center.latitude -= metersSouth / 111_320.0
        }

        withAnimation(animated ? .easeInOut(duration: 0.35) : nil) {
            position = .region(
                MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: followZoomMeters,
                    longitudinalMeters: followZoomMeters
                )
            )
        }
    }

    /// Fits the full route in view, zoomed dynamically, with room above the bottom overlay.
    private func regionFitting(
        _ coordinates: [CLLocationCoordinate2D],
        bottomContentInset: CGFloat
    ) -> MKCoordinateRegion {
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let rawLatDelta = max(maxLat - minLat, 0.0008)
        let rawLonDelta = max(maxLon - minLon, 0.0008)

        // Padding so the path isn't clipped at the edges.
        let edgePadding: Double = 1.55
        var latDelta = rawLatDelta * edgePadding
        var lonDelta = rawLonDelta * edgePadding

        // Minimum zoom so tiny routes aren't absurdly close.
        latDelta = max(latDelta, 0.0035)
        lonDelta = max(lonDelta, 0.0035)

        var center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Shift camera south so the route sits in the visible band above the overlay card.
        if bottomContentInset > 0 {
            let bottomBias = min(0.42, Double(bottomContentInset) / 700.0)
            latDelta *= (1.0 + bottomBias)
            center.latitude -= latDelta * bottomBias * 0.45
        }

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
}
