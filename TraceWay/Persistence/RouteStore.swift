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

/// Result of importing a `TraceWaySharedRoute` into SwiftData.
enum RouteImportResult: Equatable {
    case imported(Route)
    case alreadyExists(Route)

    static func == (lhs: RouteImportResult, rhs: RouteImportResult) -> Bool {
        switch (lhs, rhs) {
        case let (.imported(a), .imported(b)),
             let (.alreadyExists(a), .alreadyExists(b)):
            return a.id == b.id
        default:
            return false
        }
    }
}

enum RouteStoreError: Error, LocalizedError, Equatable {
    case emptyRoute
    case persistenceFailed(String)
    case invalidImport(String)
    case tooManyPoints(Int)

    var errorDescription: String? {
        switch self {
        case .emptyRoute:
            "Cannot save a route with no recorded points."
        case let .persistenceFailed(message):
            "Failed to save route: \(message)"
        case let .invalidImport(reason):
            "Cannot import route: \(reason)"
        case let .tooManyPoints(count):
            "Cannot import route with \(count) points (maximum \(RouteImportLimits.maximumPointCount))."
        }
    }
}

/// Defensive limits for shared-route import (aligned with QR decoder ceiling).
enum RouteImportLimits {
    /// Matches `RouteQRDecoder.maximumPointCount` / encoder validation.
    static let maximumPointCount = 20_000
    static let maximumNameLength = 200
}

/// Abstraction over local route persistence for DI and testing.
@MainActor
protocol RouteStoring: AnyObject {
    func save(_ draft: RouteDraft) throws -> Route
    func fetchAll() throws -> [Route]
    func fetchRecordedRoutes() throws -> [Route]
    func fetchReceivedRoutes() throws -> [Route]
    func fetchReceivedRoute(withShareID shareID: UUID) throws -> Route?
    func importSharedRoute(_ sharedRoute: TraceWaySharedRoute) throws -> RouteImportResult
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
            shareID: UUID(),
            source: .recorded,
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

    func importSharedRoute(_ sharedRoute: TraceWaySharedRoute) throws -> RouteImportResult {
        try validateForImport(sharedRoute)

        if let existing = try fetchReceivedRoute(withShareID: sharedRoute.shareID) {
            return .alreadyExists(existing)
        }

        let first = sharedRoute.points[0]
        let last = sharedRoute.points[sharedRoute.points.count - 1]
        let quality = RouteQualitySummary(rawValue: sharedRoute.quality ?? "") ?? .unknown

        // New local `id`; transferred `shareID`; source = received.
        let route = Route(
            id: UUID(),
            shareID: sharedRoute.shareID,
            source: .received,
            name: sharedRoute.routeName.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: sharedRoute.createdAt,
            startedAt: sharedRoute.startedAt,
            endedAt: sharedRoute.endedAt,
            distanceMeters: sharedRoute.distanceMeters,
            durationSeconds: sharedRoute.durationSeconds,
            quality: quality,
            startLatitude: first.latitude,
            startLongitude: first.longitude,
            endLatitude: last.latitude,
            endLongitude: last.longitude
        )

        for (index, point) in sharedRoute.points.enumerated() {
            // Shared payload omits speed/course — persist Core Location–style placeholders.
            // speed = 0 (unknown/not shared); course = -1 (invalid/unavailable).
            let timestamp = point.timestamp
                ?? sharedRoute.startedAt.addingTimeInterval(TimeInterval(index))
            let persisted = RoutePoint(
                sequenceIndex: index,
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: timestamp,
                horizontalAccuracy: point.horizontalAccuracy ?? -1,
                speed: 0,
                course: -1,
                altitude: point.altitude
            )
            route.points.append(persisted)
        }

        modelContext.insert(route)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw RouteStoreError.persistenceFailed(error.localizedDescription)
        }

        return .imported(route)
    }

    func fetchAll() throws -> [Route] {
        var descriptor = FetchDescriptor<Route>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.points]
        return try modelContext.fetch(descriptor)
    }

    func fetchRecordedRoutes() throws -> [Route] {
        try fetchRoutes(source: .recorded)
    }

    func fetchReceivedRoutes() throws -> [Route] {
        try fetchRoutes(source: .received)
    }

    /// Duplicate detection helper — only matches **received** routes.
    func fetchReceivedRoute(withShareID shareID: UUID) throws -> Route? {
        let received = RouteSource.received.rawValue
        var descriptor = FetchDescriptor<Route>(
            predicate: #Predicate<Route> { route in
                route.shareID == shareID && route.sourceRawValue == received
            }
        )
        descriptor.fetchLimit = 1
        descriptor.relationshipKeyPathsForPrefetching = [\.points]
        return try modelContext.fetch(descriptor).first
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

    // MARK: - Private

    private func fetchRoutes(source: RouteSource) throws -> [Route] {
        let raw = source.rawValue
        var descriptor = FetchDescriptor<Route>(
            predicate: #Predicate<Route> { route in
                route.sourceRawValue == raw
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.points]
        return try modelContext.fetch(descriptor)
    }

    private func validateForImport(_ sharedRoute: TraceWaySharedRoute) throws {
        let name = sharedRoute.routeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= RouteImportLimits.maximumNameLength else {
            throw RouteStoreError.invalidImport("Invalid route name.")
        }
        guard !sharedRoute.points.isEmpty else {
            throw RouteStoreError.emptyRoute
        }
        guard sharedRoute.points.count <= RouteImportLimits.maximumPointCount else {
            throw RouteStoreError.tooManyPoints(sharedRoute.points.count)
        }
        guard sharedRoute.distanceMeters.isFinite, sharedRoute.distanceMeters >= 0 else {
            throw RouteStoreError.invalidImport("Invalid distance.")
        }
        guard sharedRoute.durationSeconds.isFinite, sharedRoute.durationSeconds >= 0 else {
            throw RouteStoreError.invalidImport("Invalid duration.")
        }

        for (index, point) in sharedRoute.points.enumerated() {
            guard point.latitude.isFinite, point.longitude.isFinite else {
                throw RouteStoreError.invalidImport("Non-finite coordinate at index \(index).")
            }
            guard (-90...90).contains(point.latitude) else {
                throw RouteStoreError.invalidImport("Latitude out of range at index \(index).")
            }
            guard (-180...180).contains(point.longitude) else {
                throw RouteStoreError.invalidImport("Longitude out of range at index \(index).")
            }
            if let altitude = point.altitude, !altitude.isFinite {
                throw RouteStoreError.invalidImport("Invalid altitude at index \(index).")
            }
            if let accuracy = point.horizontalAccuracy, !accuracy.isFinite {
                throw RouteStoreError.invalidImport("Invalid accuracy at index \(index).")
            }
        }
    }
}
