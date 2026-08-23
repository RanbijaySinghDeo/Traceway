//
//  Route.swift
//  TraceWay
//

import Foundation
import SwiftData

/// A locally persisted GPS track (recorded on-device or received via sharing).
@Model
final class Route {
    @Attribute(.unique) var id: UUID

    /// Stable identity for QR sharing / duplicate detection. Not unique across sources —
    /// a recorded route and a received route may share the same `shareID`.
    var shareID: UUID = UUID()

    /// Persisted `RouteSource` raw value. Defaults to recorded for lightweight migration.
    var sourceRawValue: String = RouteSource.recorded.rawValue

    var name: String
    var createdAt: Date
    var startedAt: Date
    var endedAt: Date

    /// Total path length in meters, computed from accepted points.
    var distanceMeters: Double

    /// Active recording duration in seconds (excludes paused time).
    var durationSeconds: TimeInterval

    /// Overall GPS quality summary raw value (`RouteQualitySummary`).
    var qualityRawValue: String

    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?

    @Relationship(deleteRule: .cascade, inverse: \RoutePoint.route)
    var points: [RoutePoint]

    init(
        id: UUID = UUID(),
        shareID: UUID = UUID(),
        source: RouteSource = .recorded,
        name: String,
        createdAt: Date = .now,
        startedAt: Date,
        endedAt: Date,
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        quality: RouteQualitySummary,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        points: [RoutePoint] = []
    ) {
        self.id = id
        self.shareID = shareID
        self.sourceRawValue = source.rawValue
        self.name = name
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.qualityRawValue = quality.rawValue
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.points = points
    }

    var source: RouteSource {
        get { RouteSource(rawValue: sourceRawValue) ?? .recorded }
        set { sourceRawValue = newValue.rawValue }
    }

    var quality: RouteQualitySummary {
        get { RouteQualitySummary(rawValue: qualityRawValue) ?? .unknown }
        set { qualityRawValue = newValue.rawValue }
    }

    /// Points sorted by capture order for map rendering and export.
    var orderedPoints: [RoutePoint] {
        points.sorted { $0.sequenceIndex < $1.sequenceIndex }
    }
}
