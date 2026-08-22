//
//  DistanceCalculator.swift
//  TraceWay
//

import CoreLocation
import Foundation

/// Path length from accepted GPS points only — never from a routing API.
enum DistanceCalculator {
    static func cumulativeDistance(of points: [LocationPoint]) -> CLLocationDistance {
        guard points.count >= 2 else { return 0 }

        var total: CLLocationDistance = 0
        for index in 1..<points.count {
            total += points[index - 1].distance(to: points[index])
        }
        return total
    }

    static func distance(from: LocationPoint, to: LocationPoint) -> CLLocationDistance {
        from.distance(to: to)
    }
}

extension Array where Element == LocationPoint {
    func summarizingQuality(
        thresholds: GPSQualityThresholds = .default
    ) -> RouteQualitySummary {
        guard !isEmpty else { return .unknown }

        let qualities = map {
            GPSQuality(horizontalAccuracyMeters: $0.horizontalAccuracy, thresholds: thresholds)
        }

        let excellent = qualities.filter { $0 == .excellent }.count
        let fair = qualities.filter { $0 == .fair }.count
        let poor = qualities.filter { $0 == .poor }.count

        if excellent == qualities.count { return .excellent }
        if fair == qualities.count { return .fair }
        if poor == qualities.count { return .poor }
        if excellent + fair + poor == 0 { return .unknown }
        return .mixed
    }
}
