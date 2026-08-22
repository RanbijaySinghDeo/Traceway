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

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

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
        // Muted dark base so the emerald route reads like the reference HUD.
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
            updateCamera(animated: false)
        }
        .onChange(of: routeCoordinates.count) { _, _ in
            updateCamera(animated: true)
        }
        .onChange(of: userCoordinate?.latitude) { _, _ in
            if followUser {
                updateCamera(animated: true)
            }
        }
    }

    private func mapPin(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(8)
            .background(TraceWayTheme.surface.opacity(0.92), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func updateCamera(animated: Bool) {
        let update: MapCameraPosition
        if fitToRoute, routeCoordinates.count >= 2 {
            update = .region(regionFitting(routeCoordinates))
        } else if followUser, let userCoordinate {
            update = .region(
                MKCoordinateRegion(
                    center: userCoordinate,
                    latitudinalMeters: 600,
                    longitudinalMeters: 600
                )
            )
        } else if let userCoordinate {
            update = .region(
                MKCoordinateRegion(
                    center: userCoordinate,
                    latitudinalMeters: 800,
                    longitudinalMeters: 800
                )
            )
        } else {
            return
        }

        withAnimation(animated ? .easeInOut(duration: 0.35) : nil) {
            position = update
        }
    }

    private func regionFitting(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
