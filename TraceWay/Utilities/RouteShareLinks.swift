//
//  RouteShareLinks.swift
//  TraceWay
//

import CoreLocation
import Foundation
import UIKit

/// Builds tappable map links for chat apps (WhatsApp shows these as openable location/route cards).
enum RouteShareLinks {
    /// Official Google Maps search/pin URL — opens a tappable location.
    /// https://developers.google.com/maps/documentation/urls/get-started#search-action
    static func locationPinURL(coordinate: CLLocationCoordinate2D) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/search/"
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: coordinateString(coordinate))
        ]
        return components.url!
    }

    /// Official Google Maps directions URL.
    /// https://developers.google.com/maps/documentation/urls/get-started#directions-action
    static func googleMapsDirectionsURL(coordinates: [CLLocationCoordinate2D]) -> URL? {
        guard let start = coordinates.first, let end = coordinates.last else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/dir/"

        var items: [URLQueryItem] = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "origin", value: coordinateString(start)),
            URLQueryItem(name: "destination", value: coordinateString(end)),
            URLQueryItem(name: "travelmode", value: "driving")
        ]

        let waypoints = sampledWaypoints(from: coordinates, maxIntermediate: 8)
        if !waypoints.isEmpty {
            // Google expects pipe-separated lat,lng pairs.
            let value = waypoints.map(coordinateString).joined(separator: "|")
            items.append(URLQueryItem(name: "waypoints", value: value))
        }

        components.queryItems = items
        return components.url
    }

    static func appleMapsDirectionsURL(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "saddr", value: coordinateString(start)),
            URLQueryItem(name: "daddr", value: coordinateString(end)),
            URLQueryItem(name: "dirflg", value: "d")
        ]
        return components.url
    }

    /// Compact WhatsApp body with one primary tappable location + optional route link.
    static func whatsAppMessage(
        routeName: String,
        coordinates: [CLLocationCoordinate2D],
        distanceMeters: Double,
        durationSeconds: TimeInterval
    ) -> String {
        guard let end = coordinates.last else {
            return "📍 \(routeName) — shared from TraceWay"
        }

        let locationLink = locationPinURL(coordinate: end).absoluteString
        let routeLink = googleMapsDirectionsURL(coordinates: coordinates)?.absoluteString

        var lines = [
            "📍 \(routeName)",
            "\(TraceWayFormatters.distance(distanceMeters)) • \(TraceWayFormatters.duration(durationSeconds))",
            "",
            locationLink
        ]

        if let routeLink, routeLink != locationLink {
            lines.append("")
            lines.append("Route:")
            lines.append(routeLink)
        }

        return lines.joined(separator: "\n")
    }

    /// Opens WhatsApp with a prefilled tappable maps message.
    /// Uses `URLComponents` so `?` / `&` inside Maps links are encoded correctly.
    @MainActor
    static func shareViaWhatsApp(
        routeName: String,
        coordinates: [CLLocationCoordinate2D],
        distanceMeters: Double,
        durationSeconds: TimeInterval
    ) -> Bool {
        let message = whatsAppMessage(
            routeName: routeName,
            coordinates: coordinates,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds
        )

        if ExternalMapsOpener.canOpenWhatsApp(),
           let nativeURL = makeWhatsAppURL(scheme: "whatsapp", message: message) {
            UIApplication.shared.open(nativeURL)
            return true
        }

        if let webURL = makeWhatsAppURL(scheme: "https", message: message) {
            UIApplication.shared.open(webURL)
            return true
        }

        return false
    }

    /// Builds `whatsapp://send?text=…` or `https://wa.me/?text=…` with correct encoding.
    static func makeWhatsAppURL(scheme: String, message: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme

        if scheme == "whatsapp" {
            components.host = "send"
            components.queryItems = [URLQueryItem(name: "text", value: message)]
        } else {
            components.host = "wa.me"
            components.path = "/"
            components.queryItems = [URLQueryItem(name: "text", value: message)]
        }

        return components.url
    }

    static func coordinateString(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
    }

    /// Evenly sample intermediate points so the Maps link roughly follows the recorded path.
    private static func sampledWaypoints(
        from coordinates: [CLLocationCoordinate2D],
        maxIntermediate: Int
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2, maxIntermediate > 0 else { return [] }

        let intermediate = Array(coordinates.dropFirst().dropLast())
        guard intermediate.count > maxIntermediate else { return intermediate }

        var samples: [CLLocationCoordinate2D] = []
        let step = Double(intermediate.count - 1) / Double(maxIntermediate)
        for index in 0..<maxIntermediate {
            let sampleIndex = min(Int((Double(index) * step).rounded()), intermediate.count - 1)
            samples.append(intermediate[sampleIndex])
        }
        return samples
    }
}
