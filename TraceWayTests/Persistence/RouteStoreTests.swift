//
//  RouteStoreTests.swift
//  TraceWayTests
//

import CoreLocation
import SwiftData
import XCTest
@testable import TraceWay

@MainActor
final class RouteStoreTests: XCTestCase {
    private var dependencies: AppDependencies!
    private var store: RouteStore!

    override func setUp() async throws {
        dependencies = AppDependencies.preview(inMemory: true)
        store = RouteStore(modelContext: dependencies.modelContainer.mainContext)
    }

    func testSaveFetchAndDeleteRoute() throws {
        let draft = RouteDraft(
            name: "Home → Office",
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_800),
            distanceMeters: 4_200,
            durationSeconds: 800,
            quality: .fair,
            points: [
                LocationPoint(
                    coordinate: .init(latitude: 28.6139, longitude: 77.2090),
                    timestamp: Date(timeIntervalSince1970: 1_000),
                    horizontalAccuracy: 8,
                    speed: 5,
                    course: 90,
                    altitude: 216
                ),
                LocationPoint(
                    coordinate: .init(latitude: 28.6145, longitude: 77.2100),
                    timestamp: Date(timeIntervalSince1970: 1_060),
                    horizontalAccuracy: 10,
                    speed: 6,
                    course: 95,
                    altitude: 217
                )
            ]
        )

        let saved = try store.save(draft)
        XCTAssertEqual(saved.name, "Home → Office")
        XCTAssertEqual(saved.orderedPoints.count, 2)
        XCTAssertEqual(saved.quality, .fair)

        try store.rename(saved, to: "Home to Office")
        XCTAssertEqual(saved.name, "Home to Office")

        let fetched = try store.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, saved.id)
        XCTAssertEqual(fetched.first?.name, "Home to Office")

        try store.delete(saved)
        XCTAssertTrue(try store.fetchAll().isEmpty)
    }

    func testSaveEmptyRouteThrows() {
        let draft = RouteDraft(
            name: "Empty",
            startedAt: .now,
            endedAt: .now,
            distanceMeters: 0,
            durationSeconds: 0,
            quality: .unknown,
            points: []
        )

        XCTAssertThrowsError(try store.save(draft)) { error in
            XCTAssertEqual(error as? RouteStoreError, .emptyRoute)
        }
    }
}
