//
//  AppDependencies.swift
//  TraceWay
//

import Foundation
import SwiftData

/// Application-wide dependency graph. Constructed once at launch and injected into features.
@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let routeStore: any RouteStoring
    let locationService: any LocationServing
    let routeExporter: any RouteExporting
    let gpsQualityThresholds: GPSQualityThresholds

    init(
        modelContainer: ModelContainer,
        routeStore: (any RouteStoring)? = nil,
        locationService: (any LocationServing)? = nil,
        routeExporter: any RouteExporting = RouteExporter(),
        gpsQualityThresholds: GPSQualityThresholds = .default
    ) {
        self.modelContainer = modelContainer
        self.routeStore = routeStore ?? RouteStore(modelContext: modelContainer.mainContext)
        self.locationService = locationService ?? LocationManager()
        self.routeExporter = routeExporter
        self.gpsQualityThresholds = gpsQualityThresholds
    }

    /// Production container wired to on-disk SwiftData and Core Location.
    static func live() -> AppDependencies {
        do {
            let schema = Schema([Route.self, RoutePoint.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return AppDependencies(modelContainer: container)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// In-memory container for SwiftUI previews and tests.
    static func preview(
        inMemory: Bool = true,
        locationService: (any LocationServing)? = nil
    ) -> AppDependencies {
        do {
            let schema = Schema([Route.self, RoutePoint.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return AppDependencies(
                modelContainer: container,
                locationService: locationService
            )
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }
}
