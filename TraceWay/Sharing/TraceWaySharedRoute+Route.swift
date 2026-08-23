//
//  TraceWaySharedRoute+Route.swift
//  TraceWay
//

import Foundation

extension TraceWaySharedRoute {
    /// Builds a share DTO from a persisted route. Uses `route.shareID` (stable across shares).
    /// Point order follows `orderedPoints` (sequenceIndex), not timestamps.
    static func from(route: Route) -> TraceWaySharedRoute {
        let ordered = route.orderedPoints
        let points = ordered.map { point in
            TraceWaySharedRoutePoint(
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: point.timestamp,
                altitude: point.altitude,
                horizontalAccuracy: point.horizontalAccuracy >= 0 ? point.horizontalAccuracy : nil
            )
        }

        return TraceWaySharedRoute(
            version: TraceWaySharedRoute.currentVersion,
            shareID: route.shareID,
            routeName: route.name,
            createdAt: route.createdAt,
            startedAt: route.startedAt,
            endedAt: route.endedAt,
            distanceMeters: route.distanceMeters,
            durationSeconds: route.durationSeconds,
            quality: route.qualityRawValue,
            points: points
        )
    }
}
