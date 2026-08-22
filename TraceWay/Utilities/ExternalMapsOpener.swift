//
//  ExternalMapsOpener.swift
//  TraceWay
//

import CoreLocation
import Foundation
import UIKit

/// Opens start/end (or a waypoint-sampled path) in Apple Maps / Google Maps.
/// Note: third-party map apps cannot ingest our full GPS polyline via URL — GPX share is the faithful export.
enum ExternalMapsOpener {
    static func canOpenGoogleMaps() -> Bool {
        guard let url = URL(string: "comgooglemaps://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func canOpenWhatsApp() -> Bool {
        guard let url = URL(string: "whatsapp://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Opens Apple Maps with driving directions from start → end of the recorded route.
    static func openInAppleMaps(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) {
        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "saddr", value: "\(start.latitude),\(start.longitude)"),
            URLQueryItem(name: "daddr", value: "\(end.latitude),\(end.longitude)"),
            URLQueryItem(name: "dirflg", value: "d")
        ]
        guard let url = components?.url else { return }
        UIApplication.shared.open(url)
    }

    /// Opens Google Maps (app if installed, otherwise browser) start → end.
    static func openInGoogleMaps(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) {
        if canOpenGoogleMaps() {
            var components = URLComponents(string: "comgooglemaps://")
            components?.queryItems = [
                URLQueryItem(name: "saddr", value: "\(start.latitude),\(start.longitude)"),
                URLQueryItem(name: "daddr", value: "\(end.latitude),\(end.longitude)"),
                URLQueryItem(name: "directionsmode", value: "driving")
            ]
            if let url = components?.url {
                UIApplication.shared.open(url)
                return
            }
        }

        var web = URLComponents(string: "https://www.google.com/maps/dir/")
        web?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(
                name: "origin",
                value: "\(start.latitude),\(start.longitude)"
            ),
            URLQueryItem(
                name: "destination",
                value: "\(end.latitude),\(end.longitude)"
            ),
            URLQueryItem(name: "travelmode", value: "driving")
        ]
        if let url = web?.url {
            UIApplication.shared.open(url)
        }
    }
}
