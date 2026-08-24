//
//  RouteQRPathSimplifier.swift
//  TraceWay
//

import Foundation

/// Share-time only. Never mutates the stored SwiftData track.
/// Used only when a full-fidelity QR payload exceeds single-QR capacity.
enum RouteQRPathSimplifier {
    /// Comfortable single-QR budget for compact + LZFSE + EC Q/M.
    static let defaultMaxPoints = 1_000

    /// Start with a tight tolerance so short/complex shapes stay accurate.
    static let initialToleranceMeters: Double = 3.0

    /// Result of preparing a route for QR when the full track is too large.
    struct SimplificationResult: Sendable, Equatable {
        let route: TraceWaySharedRoute
        let originalPointCount: Int
        let simplifiedPointCount: Int

        var didSimplify: Bool { simplifiedPointCount < originalPointCount }
    }

    /// Reduces point count with Douglas–Peucker, then a uniform fallback if needed.
    /// Also drops altitude / horizontalAccuracy from the QR payload (coords + order matter most).
    static func simplifyForQR(
        _ route: TraceWaySharedRoute,
        maxPoints: Int = defaultMaxPoints
    ) -> SimplificationResult {
        let originalCount = route.points.count
        guard originalCount > 2 else {
            return SimplificationResult(
                route: strippingOptionalSensorFields(route),
                originalPointCount: originalCount,
                simplifiedPointCount: originalCount
            )
        }

        var tolerance = initialToleranceMeters
        var simplified = route.points
        let maxTolerance: Double = 40.0

        while simplified.count > maxPoints, tolerance <= maxTolerance {
            simplified = douglasPeucker(points: route.points, toleranceMeters: tolerance)
            tolerance *= 1.6
        }

        if simplified.count > maxPoints {
            simplified = strideSample(points: simplified, maxPoints: maxPoints)
        }

        // Always keep endpoints.
        if let first = route.points.first, let last = route.points.last {
            if simplified.first != first {
                simplified.insert(first, at: 0)
            }
            if simplified.last != last {
                simplified.append(last)
            }
            if simplified.count > maxPoints {
                simplified = strideSample(points: simplified, maxPoints: maxPoints)
                // Re-assert endpoints after stride.
                simplified[0] = first
                simplified[simplified.count - 1] = last
            }
        }

        let slimPoints = simplified.map {
            TraceWaySharedRoutePoint(
                latitude: $0.latitude,
                longitude: $0.longitude,
                timestamp: $0.timestamp,
                altitude: nil,
                horizontalAccuracy: nil
            )
        }

        let slim = TraceWaySharedRoute(
            version: route.version,
            shareID: route.shareID,
            routeName: route.routeName,
            createdAt: route.createdAt,
            startedAt: route.startedAt,
            endedAt: route.endedAt,
            distanceMeters: route.distanceMeters,
            durationSeconds: route.durationSeconds,
            quality: route.quality,
            points: slimPoints
        )

        return SimplificationResult(
            route: slim,
            originalPointCount: originalCount,
            simplifiedPointCount: slimPoints.count
        )
    }

    // MARK: - Douglas–Peucker

    private static func douglasPeucker(
        points: [TraceWaySharedRoutePoint],
        toleranceMeters: Double
    ) -> [TraceWaySharedRoutePoint] {
        guard points.count > 2 else { return points }

        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true

        var stack: [(Int, Int)] = [(0, points.count - 1)]
        while let (start, end) = stack.popLast() {
            guard end > start + 1 else { continue }

            var maxDistance = 0.0
            var maxIndex = start
            let lineStart = points[start]
            let lineEnd = points[end]

            for index in (start + 1)..<end {
                let distance = perpendicularDistanceMeters(
                    point: points[index],
                    lineStart: lineStart,
                    lineEnd: lineEnd
                )
                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = index
                }
            }

            if maxDistance > toleranceMeters {
                keep[maxIndex] = true
                stack.append((start, maxIndex))
                stack.append((maxIndex, end))
            }
        }

        return points.enumerated().compactMap { keep[$0.offset] ? $0.element : nil }
    }

    /// Uniform sample keeping first/last when DP alone cannot hit the budget.
    private static func strideSample(
        points: [TraceWaySharedRoutePoint],
        maxPoints: Int
    ) -> [TraceWaySharedRoutePoint] {
        guard points.count > maxPoints, maxPoints >= 2 else { return points }
        let lastIndex = points.count - 1
        var result: [TraceWaySharedRoutePoint] = []
        result.reserveCapacity(maxPoints)
        for i in 0..<maxPoints {
            let index = Int((Double(i) / Double(maxPoints - 1)) * Double(lastIndex))
            result.append(points[index])
        }
        return result
    }

    private static func strippingOptionalSensorFields(_ route: TraceWaySharedRoute) -> TraceWaySharedRoute {
        TraceWaySharedRoute(
            version: route.version,
            shareID: route.shareID,
            routeName: route.routeName,
            createdAt: route.createdAt,
            startedAt: route.startedAt,
            endedAt: route.endedAt,
            distanceMeters: route.distanceMeters,
            durationSeconds: route.durationSeconds,
            quality: route.quality,
            points: route.points.map {
                TraceWaySharedRoutePoint(
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    timestamp: $0.timestamp,
                    altitude: nil,
                    horizontalAccuracy: nil
                )
            }
        )
    }

    /// Approximate cross-track distance of `point` from segment start→end, in meters.
    private static func perpendicularDistanceMeters(
        point: TraceWaySharedRoutePoint,
        lineStart: TraceWaySharedRoutePoint,
        lineEnd: TraceWaySharedRoutePoint
    ) -> Double {
        let x = point.longitude
        let y = point.latitude
        let x1 = lineStart.longitude
        let y1 = lineStart.latitude
        let x2 = lineEnd.longitude
        let y2 = lineEnd.latitude

        let dx = x2 - x1
        let dy = y2 - y1
        if abs(dx) < 1e-15, abs(dy) < 1e-15 {
            return haversineMeters(lat1: y1, lon1: x1, lat2: y, lon2: x)
        }

        // Project onto the segment in degree space, then convert residual to meters.
        let t = max(0, min(1, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
        let projLon = x1 + t * dx
        let projLat = y1 + t * dy
        return haversineMeters(lat1: y, lon1: x, lat2: projLat, lon2: projLon)
    }

    private static func haversineMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let r = 6_371_000.0
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180
        let a = sin(Δφ / 2) * sin(Δφ / 2)
            + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}
