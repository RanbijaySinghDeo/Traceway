//
//  LocationPoint.swift
//  TraceWay
//

import CoreLocation
import Foundation

/// In-memory representation of an accepted GPS fix during recording.
/// Converted to `RoutePoint` only when the route is saved.
struct LocationPoint: Sendable, Equatable, Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let horizontalAccuracy: CLLocationAccuracy
    let speed: CLLocationSpeed
    let course: CLLocationDirection
    let altitude: CLLocationDistance?

    init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        timestamp: Date,
        horizontalAccuracy: CLLocationAccuracy,
        speed: CLLocationSpeed,
        course: CLLocationDirection,
        altitude: CLLocationDistance? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.course = course
        self.altitude = altitude
    }

    init(location: CLLocation, id: UUID = UUID()) {
        self.id = id
        self.coordinate = location.coordinate
        self.timestamp = location.timestamp
        self.horizontalAccuracy = location.horizontalAccuracy
        self.speed = location.speed
        self.course = location.course
        // Core Location uses a sentinel for invalid altitude; treat non-negative validity via verticalAccuracy.
        self.altitude = location.verticalAccuracy >= 0 ? location.altitude : nil
    }

    var latitude: Double { coordinate.latitude }
    var longitude: Double { coordinate.longitude }

    func distance(to other: LocationPoint) -> CLLocationDistance {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
