//
//  RoutesListViewModel.swift
//  TraceWay
//

import Foundation
import Observation

enum RoutesListSegment: String, CaseIterable, Identifiable {
    case myRoutes
    case received

    var id: String { rawValue }

    var title: String {
        switch self {
        case .myRoutes: "My Routes"
        case .received: "Received"
        }
    }
}

@MainActor
@Observable
final class RoutesListViewModel {
    private let routeStore: any RouteStoring

    var segment: RoutesListSegment = .myRoutes
    var routes: [Route] = []
    var errorMessage: String?
    var isLoading = false

    init(routeStore: any RouteStoring) {
        self.routeStore = routeStore
    }

    func load() {
        isLoading = true
        defer { isLoading = false }
        do {
            switch segment {
            case .myRoutes:
                routes = try routeStore.fetchRecordedRoutes()
            case .received:
                routes = try routeStore.fetchReceivedRoutes()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectSegment(_ segment: RoutesListSegment) {
        guard self.segment != segment else { return }
        self.segment = segment
        load()
    }

    func delete(_ route: Route) {
        do {
            try routeStore.delete(route)
            routes.removeAll { $0.id == route.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
