//
//  RoutesListViewModel.swift
//  TraceWay
//

import Foundation
import Observation

@MainActor
@Observable
final class RoutesListViewModel {
    private let routeStore: any RouteStoring

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
            routes = try routeStore.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
