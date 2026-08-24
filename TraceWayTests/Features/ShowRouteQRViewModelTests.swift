//
//  ShowRouteQRViewModelTests.swift
//  TraceWayTests
//

import CoreLocation
import SwiftData
import XCTest
@testable import TraceWay

@MainActor
final class ShowRouteQRViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var store: RouteStore!

    override func setUp() async throws {
        let schema = Schema([Route.self, RoutePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        store = RouteStore(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
    }

    func testRouteToSharedDTOPreservesShareIDMetadataAndPoints() throws {
        let draft = RouteDraft(
            name: "Office → Home",
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_800),
            distanceMeters: 4_200,
            durationSeconds: 1_080,
            quality: .fair,
            points: [
                LocationPoint(
                    coordinate: .init(latitude: 12.97, longitude: 77.59),
                    timestamp: Date(timeIntervalSince1970: 1_000),
                    horizontalAccuracy: 5,
                    speed: 3,
                    course: 90,
                    altitude: 900
                ),
                LocationPoint(
                    coordinate: .init(latitude: 12.98, longitude: 77.60),
                    timestamp: Date(timeIntervalSince1970: 1_100),
                    horizontalAccuracy: 6,
                    speed: 4,
                    course: 95,
                    altitude: 901
                ),
                LocationPoint(
                    coordinate: .init(latitude: 12.99, longitude: 77.61),
                    timestamp: Date(timeIntervalSince1970: 1_200),
                    horizontalAccuracy: 7,
                    speed: 5,
                    course: 100,
                    altitude: 902
                )
            ]
        )
        let route = try store.save(draft)
        let shareID = route.shareID

        let shared = TraceWaySharedRoute.from(route: route)

        XCTAssertEqual(shared.shareID, shareID)
        XCTAssertEqual(shared.routeName, "Office → Home")
        XCTAssertEqual(shared.distanceMeters, 4_200, accuracy: 0.01)
        XCTAssertEqual(shared.durationSeconds, 1_080, accuracy: 0.01)
        XCTAssertEqual(shared.quality, "fair")
        XCTAssertEqual(shared.points.count, 3)
        XCTAssertEqual(shared.points[0].latitude, 12.97, accuracy: 1e-9)
        XCTAssertEqual(shared.points[2].longitude, 77.61, accuracy: 1e-9)
        XCTAssertEqual(TraceWaySharedRoute.from(route: route).shareID, shareID)
    }

    func testQRPayloadGenerationSucceedsForValidRoute() throws {
        // Fixture-based encode avoids SwiftData + CI interaction flakes in the full suite.
        let shared = RouteQRTestFixtures.makeRoute(pointCount: 40, style: .straight)
        let payload = try RouteQREncoder(enforceSingleQRCapacity: false).encode(shared)
        XCTAssertTrue(payload.hasPrefix("TW1:"))
        XCTAssertGreaterThan(payload.count, 10)
    }

    func testOversizedRouteMapsToFriendlyError() throws {
        let shared = RouteQRTestFixtures.makeRoute(pointCount: 200, style: .denseUrban)
        let encoder = RouteQREncoder(
            strategy: .fullJSON,
            enforceSingleQRCapacity: true,
            errorCorrectionLevel: .h
        )

        XCTAssertThrowsError(try encoder.encode(shared)) { error in
            let facing = RouteQRUserFacingErrors.message(for: error)
            XCTAssertEqual(facing.title, "Route Too Large")
            XCTAssertTrue(facing.message.contains("too much GPS data"))
        }
    }

    private func makeDraft(name: String, pointCount: Int) -> RouteDraft {
        RouteDraft(
            name: name,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_000 + TimeInterval(pointCount)),
            distanceMeters: Double(pointCount) * 10,
            durationSeconds: TimeInterval(pointCount),
            quality: .excellent,
            points: (0..<pointCount).map { index in
                LocationPoint(
                    coordinate: .init(
                        latitude: 12.97 + Double(index) * 0.0001,
                        longitude: 77.59 + Double(index) * 0.0001
                    ),
                    timestamp: Date(timeIntervalSince1970: 1_000 + TimeInterval(index)),
                    horizontalAccuracy: 5,
                    speed: 2,
                    course: 90,
                    altitude: 900
                )
            }
        )
    }
}
