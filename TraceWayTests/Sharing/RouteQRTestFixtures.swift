//
//  RouteQRTestFixtures.swift
//  TraceWayTests
//

import CoreLocation
import Foundation
@testable import TraceWay

enum RouteQRTestFixtures {
    /// Deterministic urban-ish track near Bengaluru.
    static func makeRoute(
        pointCount: Int,
        style: TrackStyle,
        shareID: UUID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
        includeOptionalFields: Bool = true
    ) -> TraceWaySharedRoute {
        precondition(pointCount > 0)

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var points: [TraceWaySharedRoutePoint] = []

        var latitude = 12.971600
        var longitude = 77.594600

        for index in 0..<pointCount {
            switch style {
            case .straight:
                latitude += 0.000090 // ~10 m north
            case .curved:
                let angle = Double(index) * 0.05
                latitude += 0.000080 * cos(angle)
                longitude += 0.000080 * sin(angle)
            case .frequentTurns:
                if index % 4 == 0 {
                    latitude += 0.000070
                } else if index % 4 == 1 {
                    longitude += 0.000070
                } else if index % 4 == 2 {
                    latitude -= 0.000040
                } else {
                    longitude -= 0.000040
                }
            case .denseUrban:
                latitude += 0.000025 + Double(index % 3) * 0.000005
                longitude += (index % 2 == 0 ? 0.000030 : -0.000015)
            case .narrowParallel:
                // Simulate staying on a narrow lane beside a parallel road (~8–12 m offset noise).
                latitude += 0.000055
                longitude += 0.000004 + sin(Double(index) * 0.35) * 0.000008
            case .longHighway:
                latitude += 0.000180
                longitude += 0.000020
            }

            let timestamp = start.addingTimeInterval(TimeInterval(index * 2))
            points.append(
                TraceWaySharedRoutePoint(
                    latitude: latitude,
                    longitude: longitude,
                    timestamp: includeOptionalFields ? timestamp : nil,
                    altitude: includeOptionalFields ? 900 + Double(index % 20) : nil,
                    horizontalAccuracy: includeOptionalFields ? 5 + Double(index % 4) : nil
                )
            )
        }

        let distance = approximateDistanceMeters(points)
        return TraceWaySharedRoute(
            version: TraceWaySharedRoute.currentVersion,
            shareID: shareID,
            routeName: "Test \(style.rawValue) \(pointCount)",
            createdAt: start,
            startedAt: start,
            endedAt: start.addingTimeInterval(TimeInterval(max(pointCount - 1, 0) * 2)),
            distanceMeters: distance,
            durationSeconds: TimeInterval(max(pointCount - 1, 0) * 2),
            quality: "fair",
            points: points
        )
    }

    enum TrackStyle: String {
        case straight
        case curved
        case frequentTurns
        case denseUrban
        case narrowParallel
        case longHighway
    }

    static func approximateDistanceMeters(_ points: [TraceWaySharedRoutePoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for index in 1..<points.count {
            let a = CLLocation(latitude: points[index - 1].latitude, longitude: points[index - 1].longitude)
            let b = CLLocation(latitude: points[index].latitude, longitude: points[index].longitude)
            total += a.distance(from: b)
        }
        return total
    }

    static func maxCoordinateDeltaMeters(original: TraceWaySharedRoute, decoded: TraceWaySharedRoute) -> Double {
        zip(original.points, decoded.points).reduce(0.0) { partial, pair in
            let a = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let b = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            return max(partial, a.distance(from: b))
        }
    }
}
