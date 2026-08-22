//
//  RouteProcessingConfiguration.swift
//  TraceWay
//

import Foundation

/// All route-filtering thresholds in one place for field tuning (India narrow roads).
struct RouteProcessingConfiguration: Sendable, Equatable {
    var qualityThresholds: GPSQualityThresholds

    /// Reject points older than this relative to "now" (stale cache / deferred fixes).
    var maximumLocationAge: TimeInterval

    /// Reject near-identical consecutive fixes (meters).
    var duplicateDistanceMeters: CLLocationDistanceMeters

    /// Minimum movement to accept a new point. Kept low so colony-lane turns survive.
    var minimumMovementMeters: CLLocationDistanceMeters

    /// Implied speed above this between accepted points is treated as an impossible GPS jump.
    var maximumImpliedSpeedMetersPerSecond: Double

    /// Reject timestamps earlier than the previous accepted point by more than this skew.
    var maximumTimestampRewind: TimeInterval

    static let `default` = RouteProcessingConfiguration(
        qualityThresholds: .default,
        maximumLocationAge: 15,
        duplicateDistanceMeters: 0.5,
        minimumMovementMeters: 1.5,
        // ~180 km/h — high enough for highways, low enough to catch teleport jumps.
        maximumImpliedSpeedMetersPerSecond: 50,
        maximumTimestampRewind: 1
    )

    var maximumAcceptableAccuracyMeters: CLLocationAccuracyMeters {
        qualityThresholds.maximumAcceptableAccuracyMeters
    }
}

typealias CLLocationDistanceMeters = Double

enum RoutePointRejectionReason: String, Sendable, Equatable {
    case invalidAccuracy
    case poorAccuracy
    case stale
    case invalidTimestamp
    case duplicate
    case insufficientMovement
    case impossibleJump
    case notRecording
}

enum RoutePointEvaluation: Sendable, Equatable {
    case accept(LocationPoint)
    case reject(RoutePointRejectionReason)
}
