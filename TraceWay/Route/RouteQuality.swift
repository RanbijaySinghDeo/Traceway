//
//  RouteQuality.swift
//  TraceWay
//

import Foundation

/// Tunable thresholds for live GPS quality UI and filtering.
/// Keep all accuracy cutoffs here so they can be adjusted after field testing in India.
struct GPSQualityThresholds: Sendable, Equatable {
    /// horizontalAccuracy ≤ this → Excellent (green).
    var excellentMaxMeters: CLLocationAccuracyMeters

    /// horizontalAccuracy ≤ this (and above excellent) → Fair (yellow).
    /// Above this → Poor (red).
    var fairMaxMeters: CLLocationAccuracyMeters

    /// Points worse than this accuracy are rejected by the route processor.
    var maximumAcceptableAccuracyMeters: CLLocationAccuracyMeters

    static let `default` = GPSQualityThresholds(
        excellentMaxMeters: 10,
        fairMaxMeters: 25,
        maximumAcceptableAccuracyMeters: 50
    )
}

/// Meters typealias so accuracy values stay explicit in configuration.
typealias CLLocationAccuracyMeters = Double

/// Live GPS quality for the recording HUD.
enum GPSQuality: String, Sendable, Equatable {
    case excellent
    case fair
    case poor
    case unknown

    init(horizontalAccuracyMeters: Double, thresholds: GPSQualityThresholds = .default) {
        guard horizontalAccuracyMeters >= 0 else {
            self = .unknown
            return
        }

        if horizontalAccuracyMeters <= thresholds.excellentMaxMeters {
            self = .excellent
        } else if horizontalAccuracyMeters <= thresholds.fairMaxMeters {
            self = .fair
        } else {
            self = .poor
        }
    }

    var displayTitle: String {
        switch self {
        case .excellent: "Excellent"
        case .fair: "Fair"
        case .poor: "Poor"
        case .unknown: "Unknown"
        }
    }

    var symbolName: String {
        switch self {
        case .excellent: "circle.fill"
        case .fair: "circle.fill"
        case .poor: "circle.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

/// Aggregate quality stored with a saved route (derived from accepted points).
enum RouteQualitySummary: String, Sendable, Codable, CaseIterable {
    case excellent
    case fair
    case poor
    case mixed
    case unknown
}
