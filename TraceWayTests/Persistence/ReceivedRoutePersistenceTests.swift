//
//  ReceivedRoutePersistenceTests.swift
//  TraceWayTests
//

import CoreLocation
import SwiftData
import XCTest
@testable import TraceWay

@MainActor
final class ReceivedRoutePersistenceTests: XCTestCase {
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

    // MARK: - Helpers

    private func makeSharedRoute(
        shareID: UUID = UUID(),
        name: String = "Home → Farmhouse",
        pointCount: Int = 5,
        scrambleTimestamps: Bool = false
    ) -> TraceWaySharedRoute {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var points: [TraceWaySharedRoutePoint] = []
        for index in 0..<pointCount {
            let timestamp: Date
            if scrambleTimestamps {
                // Deliberately non-monotonic vs sequence order.
                timestamp = start.addingTimeInterval(TimeInterval((pointCount - index) * 10))
            } else {
                timestamp = start.addingTimeInterval(TimeInterval(index * 2))
            }
            points.append(
                TraceWaySharedRoutePoint(
                    latitude: 12.9716 + Double(index) * 0.0001,
                    longitude: 77.5946 + Double(index) * 0.0001,
                    timestamp: timestamp,
                    altitude: 900 + Double(index),
                    horizontalAccuracy: 8
                )
            )
        }
        return TraceWaySharedRoute(
            shareID: shareID,
            routeName: name,
            createdAt: start,
            startedAt: start,
            endedAt: start.addingTimeInterval(TimeInterval(max(pointCount - 1, 0) * 2)),
            distanceMeters: 420,
            durationSeconds: TimeInterval(max(pointCount - 1, 0) * 2),
            quality: "fair",
            points: points
        )
    }

    private func makeRecordedDraft(name: String, shareIDHint _: UUID? = nil) -> RouteDraft {
        RouteDraft(
            name: name,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_800),
            distanceMeters: 1_000,
            durationSeconds: 800,
            quality: .excellent,
            points: [
                LocationPoint(
                    coordinate: .init(latitude: 28.6139, longitude: 77.2090),
                    timestamp: Date(timeIntervalSince1970: 1_000),
                    horizontalAccuracy: 5,
                    speed: 4,
                    course: 90,
                    altitude: 200
                ),
                LocationPoint(
                    coordinate: .init(latitude: 28.6145, longitude: 77.2100),
                    timestamp: Date(timeIntervalSince1970: 1_060),
                    horizontalAccuracy: 6,
                    speed: 5,
                    course: 95,
                    altitude: 201
                )
            ]
        )
    }

    // MARK: - Tests

    func testImportNewRoute() throws {
        let shareID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let shared = makeSharedRoute(shareID: shareID, pointCount: 7)

        let result = try store.importSharedRoute(shared)
        guard case let .imported(route) = result else {
            return XCTFail("Expected .imported")
        }

        XCTAssertEqual(route.source, .received)
        XCTAssertEqual(route.shareID, shareID)
        XCTAssertEqual(route.name, "Home → Farmhouse")
        XCTAssertEqual(route.distanceMeters, 420, accuracy: 0.01)
        XCTAssertEqual(route.durationSeconds, 12, accuracy: 0.01)
        XCTAssertEqual(route.createdAt.timeIntervalSince1970, shared.createdAt.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(route.startedAt.timeIntervalSince1970, shared.startedAt.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(route.endedAt.timeIntervalSince1970, shared.endedAt.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(route.qualityRawValue, "fair")
        XCTAssertEqual(route.orderedPoints.count, 7)

        for (index, point) in route.orderedPoints.enumerated() {
            XCTAssertEqual(point.sequenceIndex, index)
            XCTAssertEqual(point.latitude, shared.points[index].latitude, accuracy: 1e-9)
            XCTAssertEqual(point.longitude, shared.points[index].longitude, accuracy: 1e-9)
            XCTAssertEqual(point.speed, 0, accuracy: 0.001)
            XCTAssertEqual(point.course, -1, accuracy: 0.001)
        }
    }

    func testImportedRouteGetsNewLocalID() throws {
        let shareID = UUID()
        let shared = makeSharedRoute(shareID: shareID)
        // DTO has no sender Route.id — receiver always allocates a new local id.
        let senderLocalID = UUID()

        guard case let .imported(route) = try store.importSharedRoute(shared) else {
            return XCTFail("Expected .imported")
        }

        XCTAssertEqual(route.shareID, shareID)
        XCTAssertNotEqual(route.id, senderLocalID)
        XCTAssertNotEqual(route.id, shareID)
    }

    func testDuplicateImportReturnsAlreadyExists() throws {
        let shareID = UUID()
        let shared = makeSharedRoute(shareID: shareID)

        let first = try store.importSharedRoute(shared)
        let second = try store.importSharedRoute(shared)

        guard case let .imported(imported) = first else {
            return XCTFail("Expected first import to succeed")
        }
        guard case let .alreadyExists(existing) = second else {
            return XCTFail("Expected second import to be duplicate")
        }

        XCTAssertEqual(imported.id, existing.id)
        XCTAssertEqual(try store.fetchReceivedRoutes().count, 1)
    }

    func testSameShareIDRecordedDoesNotBlockReceivedImport() throws {
        let shareID = UUID()
        let recorded = try store.save(makeRecordedDraft(name: "Local walk"))
        // Force the recorded route to reuse the incoming shareID (collision scenario).
        recorded.shareID = shareID
        try container.mainContext.save()

        let shared = makeSharedRoute(shareID: shareID, name: "Received copy")
        let result = try store.importSharedRoute(shared)

        guard case let .imported(received) = result else {
            return XCTFail("Expected import to succeed beside recorded route")
        }

        XCTAssertEqual(received.source, .received)
        XCTAssertEqual(received.shareID, shareID)
        XCTAssertEqual(try store.fetchRecordedRoutes().count, 1)
        XCTAssertEqual(try store.fetchReceivedRoutes().count, 1)
        XCTAssertEqual(try store.fetchAll().count, 2)
    }

    func testFetchRecordedRoutes() throws {
        _ = try store.save(makeRecordedDraft(name: "R1"))
        _ = try store.save(makeRecordedDraft(name: "R2"))
        _ = try store.importSharedRoute(makeSharedRoute(name: "Recv1"))
        _ = try store.importSharedRoute(makeSharedRoute(name: "Recv2"))

        let recorded = try store.fetchRecordedRoutes()
        XCTAssertEqual(recorded.count, 2)
        XCTAssertTrue(recorded.allSatisfy { $0.source == .recorded })
        XCTAssertEqual(Set(recorded.map(\.name)), Set(["R1", "R2"]))
    }

    func testFetchReceivedRoutes() throws {
        _ = try store.save(makeRecordedDraft(name: "R1"))
        _ = try store.save(makeRecordedDraft(name: "R2"))
        _ = try store.importSharedRoute(makeSharedRoute(name: "Recv1"))
        _ = try store.importSharedRoute(makeSharedRoute(name: "Recv2"))

        let received = try store.fetchReceivedRoutes()
        XCTAssertEqual(received.count, 2)
        XCTAssertTrue(received.allSatisfy { $0.source == .received })
        XCTAssertEqual(Set(received.map(\.name)), Set(["Recv1", "Recv2"]))
    }

    func testPointOrderingPreservedDespiteScrambledTimestamps() throws {
        let shared = makeSharedRoute(pointCount: 4, scrambleTimestamps: true)
        guard case let .imported(route) = try store.importSharedRoute(shared) else {
            return XCTFail("Expected .imported")
        }

        let ordered = route.orderedPoints
        XCTAssertEqual(ordered.map(\.sequenceIndex), [0, 1, 2, 3])
        for index in 0..<4 {
            XCTAssertEqual(ordered[index].latitude, shared.points[index].latitude, accuracy: 1e-9)
            // Timestamps intentionally out of order vs sequence — still bound to DTO order.
            XCTAssertEqual(
                ordered[index].timestamp.timeIntervalSince1970,
                shared.points[index].timestamp!.timeIntervalSince1970,
                accuracy: 0.01
            )
        }
        // Confirm timestamps are not sorted ascending.
        let times = ordered.map(\.timestamp.timeIntervalSince1970)
        XCTAssertFalse(times[0] < times[1] && times[1] < times[2] && times[2] < times[3])
    }

    func testStartEndCoordinatesFromFirstAndLastPoints() throws {
        let shared = makeSharedRoute(pointCount: 5)
        guard case let .imported(route) = try store.importSharedRoute(shared) else {
            return XCTFail("Expected .imported")
        }

        XCTAssertEqual(route.startLatitude!, shared.points.first!.latitude, accuracy: 1e-9)
        XCTAssertEqual(route.startLongitude!, shared.points.first!.longitude, accuracy: 1e-9)
        XCTAssertEqual(route.endLatitude!, shared.points.last!.latitude, accuracy: 1e-9)
        XCTAssertEqual(route.endLongitude!, shared.points.last!.longitude, accuracy: 1e-9)
    }

    func testImportEmptyPointsThrowsAndPersistsNothing() throws {
        let empty = TraceWaySharedRoute(
            routeName: "Empty",
            createdAt: .now,
            startedAt: .now,
            endedAt: .now,
            distanceMeters: 0,
            durationSeconds: 0,
            points: []
        )

        XCTAssertThrowsError(try store.importSharedRoute(empty)) { error in
            XCTAssertEqual(error as? RouteStoreError, .emptyRoute)
        }
        XCTAssertTrue(try store.fetchAll().isEmpty)
    }

    func testExistingSavedRoutesDefaultToRecordedWithShareID() throws {
        let saved = try store.save(makeRecordedDraft(name: "Legacy-style save"))
        XCTAssertEqual(saved.source, .recorded)
        XCTAssertNotNil(saved.shareID)

        let fetched = try store.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.source, .recorded)
        XCTAssertEqual(fetched.first?.shareID, saved.shareID)
        XCTAssertEqual(try store.fetchRecordedRoutes().count, 1)
        XCTAssertTrue(try store.fetchReceivedRoutes().isEmpty)
    }

    func testImportedRouteIsFetchableAfterSave() throws {
        // Verifies the import is queryable from SwiftData after save (not only via the
        // retained object). A second on-disk ModelContainer in the same XCTest process
        // currently trips a SwiftData allocator crash on this simulator/runtime, so we
        // assert persistence via a fresh fetch on the same container instead.
        let shareID = UUID()
        let shared = makeSharedRoute(shareID: shareID, name: "Persisted QR")

        guard case let .imported(imported) = try store.importSharedRoute(shared) else {
            return XCTFail("Expected .imported")
        }
        let localID = imported.id

        let byShare = try store.fetchReceivedRoute(withShareID: shareID)
        XCTAssertEqual(byShare?.id, localID)
        XCTAssertEqual(byShare?.shareID, shareID)
        XCTAssertEqual(byShare?.name, "Persisted QR")
        XCTAssertEqual(byShare?.source, .received)
        XCTAssertEqual(byShare?.orderedPoints.count, shared.points.count)

        let received = try store.fetchReceivedRoutes()
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.id, localID)
    }

    func testRenameAndDeleteStillWorkOnReceivedRoutes() throws {
        guard case let .imported(route) = try store.importSharedRoute(makeSharedRoute()) else {
            return XCTFail("Expected .imported")
        }

        try store.rename(route, to: "Renamed Received")
        XCTAssertEqual(route.name, "Renamed Received")

        try store.delete(route)
        XCTAssertTrue(try store.fetchReceivedRoutes().isEmpty)
    }
}
