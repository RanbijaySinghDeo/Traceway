//
//  RouteStore.swift
//  TraceWay
//

import Foundation
import SwiftData

/// Draft payload used when persisting a finished recording.
struct RouteDraft: Sendable, Equatable {
    var name: String
    var startedAt: Date
    var endedAt: Date
    var distanceMeters: Double
    var durationSeconds: TimeInterval
    var quality: RouteQualitySummary
    var points: [LocationPoint]
}

enum RouteStoreError: Error, LocalizedError, Equatable {
    case emptyRoute
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyRoute:
            "Cannot save a route with no recorded points."
        case let .persistenceFailed(message):
            "Failed to save route: \(message)"
        }
    }
}

/// Abstraction over local route persistence for DI and testing.
@MainActor
protocol RouteStoring: AnyObject {
    func save(_ draft: RouteDraft) throws -> Route
    func fetchAll() throws -> [Route]
    func delete(_ route: Route) throws
    func rename(_ route: Route, to name: String) throws
}

/// SwiftData-backed store. Writes happen on stop/save, not per GPS fix.
@MainActor
final class RouteStore: RouteStoring {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ draft: RouteDraft) throws -> Route {
        guard !draft.points.isEmpty else {
            throw RouteStoreError.emptyRoute
        }

        let ordered = draft.points
        let start = ordered.first
        let end = ordered.last

        let route = Route(
            name: draft.name,
            startedAt: draft.startedAt,
            endedAt: draft.endedAt,
            distanceMeters: draft.distanceMeters,
            durationSeconds: draft.durationSeconds,
            quality: draft.quality,
            startLatitude: start?.latitude,
            startLongitude: start?.longitude,
            endLatitude: end?.latitude,
            endLongitude: end?.longitude
        )

        for (index, point) in ordered.enumerated() {
            let persisted = RoutePoint(
                sequenceIndex: index,
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: point.timestamp,
                horizontalAccuracy: point.horizontalAccuracy,
                speed: point.speed,
                course: point.course,
                altitude: point.altitude
            )
            // Assign relationship from the parent side only to avoid SwiftData double-insert hangs.
            route.points.append(persisted)
        }

        modelContext.insert(route)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw RouteStoreError.persistenceFailed(error.localizedDescription)
        }

        return route
    }

    func fetchAll() throws -> [Route] {
        var descriptor = FetchDescriptor<Route>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.points]
        return try modelContext.fetch(descriptor)
    }

    func delete(_ route: Route) throws {
        modelContext.delete(route)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw RouteStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    func rename(_ route: Route, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RouteStoreError.persistenceFailed("Route name cannot be empty.")
        }
        route.name = trimmed
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw RouteStoreError.persistenceFailed(error.localizedDescription)
        }
    }
}
