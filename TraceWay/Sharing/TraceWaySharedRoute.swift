//
//  TraceWaySharedRoute.swift
//  TraceWay
//

import Foundation

/// Versioned, SwiftData-independent transport DTO for offline QR route sharing.
/// Contains the actual GPS track — never a Maps directions URL.
struct TraceWaySharedRoute: Codable, Sendable, Equatable {
    /// Format version. Decoder rejects unsupported values.
    let version: Int

    /// Stable identity for duplicate detection (no backend required).
    let shareID: UUID

    let routeName: String
    let createdAt: Date
    let startedAt: Date
    let endedAt: Date
    let distanceMeters: Double
    let durationSeconds: TimeInterval
    let quality: String?
    let points: [TraceWaySharedRoutePoint]

    static let currentVersion = 1

    /// Approximate meters-per-degree at the equator (for precision documentation/tests).
    static let metersPerDegreeAtEquator: Double = 111_320

    init(
        version: Int = Self.currentVersion,
        shareID: UUID = UUID(),
        routeName: String,
        createdAt: Date,
        startedAt: Date,
        endedAt: Date,
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        quality: String? = nil,
        points: [TraceWaySharedRoutePoint]
    ) {
        self.version = version
        self.shareID = shareID
        self.routeName = routeName
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.quality = quality
        self.points = points
    }
}

/// One GPS fix in the shared track.
/// Order in `TraceWaySharedRoute.points` is capture order (essential).
struct TraceWaySharedRoutePoint: Codable, Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date?
    let altitude: Double?
    let horizontalAccuracy: Double?

    init(
        latitude: Double,
        longitude: Double,
        timestamp: Date? = nil,
        altitude: Double? = nil,
        horizontalAccuracy: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
    }
}

// MARK: - Wire representation choices (measured in capacity tests)

/// How coordinates are packed into the QR wire payload.
enum RouteQRCoordinateStrategy: String, Sendable, CaseIterable {
    /// Full Double lat/lon JSON (Approach A).
    case fullJSON

    /// Microdegree integers (1e-6°) with delta encoding (Approach B).
    /// ~0.11 m positional quantum at equator — preserves narrow-road fidelity better than 1e-5.
    case compactMicrodegreeDeltas
}

/// Declared precision for the compact strategy (degrees).
enum RouteQRCoordinatePrecision: Sendable {
    /// 1e-6 degrees ≈ 0.111 m at equator.
    static let microdegreesScale: Double = 1_000_000
    static let degreesQuantum: Double = 1.0 / microdegreesScale
    static let approximateMetersAtEquator: Double = TraceWaySharedRoute.metersPerDegreeAtEquator * degreesQuantum
}
