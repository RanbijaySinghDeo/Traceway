//
//  RoutePoint.swift
//  TraceWay
//

import Foundation
import SwiftData

/// A single accepted GPS fix persisted as part of a recorded route.
@Model
final class RoutePoint {
    /// Stable ordering within the parent route (0-based).
    var sequenceIndex: Int

    var latitude: Double
    var longitude: Double
    var timestamp: Date

    /// Horizontal accuracy in meters from Core Location.
    var horizontalAccuracy: Double

    /// Speed in meters per second. Negative values mean Core Location reported an invalid speed.
    var speed: Double

    /// Course in degrees relative to true north. Negative values mean invalid/unavailable.
    var course: Double

    /// Altitude in meters when available.
    var altitude: Double?

    var route: Route?

    init(
        sequenceIndex: Int,
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        horizontalAccuracy: Double,
        speed: Double,
        course: Double,
        altitude: Double? = nil,
        route: Route? = nil
    ) {
        self.sequenceIndex = sequenceIndex
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.course = course
        self.altitude = altitude
        self.route = route
    }
}
