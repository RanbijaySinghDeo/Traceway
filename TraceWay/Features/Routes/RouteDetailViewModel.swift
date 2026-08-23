//
//  RouteDetailViewModel.swift
//  TraceWay
//

import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class RouteDetailViewModel {
    private let routeStore: any RouteStoring
    private let exporter: any RouteExporting

    let route: Route
    var routeName: String
    var errorMessage: String?
    var shareURL: URL?
    var didDelete = false
    var isEditingName = false

    var coordinates: [CLLocationCoordinate2D] {
        route.orderedPoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var startCoordinate: CLLocationCoordinate2D? {
        guard let lat = route.startLatitude, let lon = route.startLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var endCoordinate: CLLocationCoordinate2D? {
        guard let lat = route.endLatitude, let lon = route.endLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var locationPoints: [LocationPoint] {
        route.orderedPoints.map { point in
            LocationPoint(
                coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                timestamp: point.timestamp,
                horizontalAccuracy: point.horizontalAccuracy,
                speed: point.speed,
                course: point.course,
                altitude: point.altitude
            )
        }
    }

    init(
        route: Route,
        routeStore: any RouteStoring,
        exporter: any RouteExporting = RouteExporter()
    ) {
        self.route = route
        self.routeStore = routeStore
        self.exporter = exporter
        self.routeName = route.name
    }

    func prepareShareGPX() {
        do {
            shareURL = try exporter.writeTemporaryGPXFile(
                name: route.name,
                points: locationPoints,
                createdAt: route.createdAt
            )
        } catch {
            errorMessage = error.localizedDescription
            shareURL = nil
        }
    }

    func saveName() {
        do {
            try routeStore.rename(route, to: routeName)
            isEditingName = false
        } catch {
            errorMessage = error.localizedDescription
            routeName = route.name
        }
    }

    func cancelEditName() {
        routeName = route.name
        isEditingName = false
    }

    func deleteRoute() {
        do {
            try routeStore.delete(route)
            didDelete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
