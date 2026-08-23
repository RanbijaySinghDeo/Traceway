//
//  RouteQRScannerViewModelTests.swift
//  TraceWayTests
//

import SwiftData
import XCTest
@testable import TraceWay

@MainActor
final class RouteQRScannerViewModelTests: XCTestCase {
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

    func testDecodeAndImportSharedRoute() throws {
        let shared = makeShared(shareID: UUID(), name: "Farm → Home")
        let payload = try RouteQREncoder(enforceSingleQRCapacity: false).encode(shared)

        let decoded = try RouteQRDecoder().decode(payload)
        let result = try store.importSharedRoute(decoded)

        guard case let .imported(route) = result else {
            return XCTFail("Expected imported")
        }
        XCTAssertEqual(route.source, .received)
        XCTAssertEqual(route.shareID, shared.shareID)
        XCTAssertEqual(route.name, "Farm → Home")
        XCTAssertEqual(try store.fetchReceivedRoutes().count, 1)
    }

    func testDuplicateImportReturnsAlreadyExists() throws {
        let shared = makeShared(shareID: UUID(), name: "Dup")
        _ = try store.importSharedRoute(shared)
        let second = try store.importSharedRoute(shared)

        guard case .alreadyExists = second else {
            return XCTFail("Expected alreadyExists")
        }
        XCTAssertEqual(try store.fetchReceivedRoutes().count, 1)
    }

    func testInvalidPayloadMapsToFriendlyCopy() {
        let facing = RouteQRUserFacingErrors.message(for: RouteQRDecodingError.invalidFormat)
        XCTAssertEqual(facing.title, "Invalid QR Code")
        XCTAssertTrue(facing.message.contains("isn't a TraceWay route"))
    }

    private func makeShared(shareID: UUID, name: String) -> TraceWaySharedRoute {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let points = (0..<20).map { index in
            TraceWaySharedRoutePoint(
                latitude: 12.97 + Double(index) * 0.0001,
                longitude: 77.59 + Double(index) * 0.0001,
                timestamp: start.addingTimeInterval(TimeInterval(index)),
                altitude: 900,
                horizontalAccuracy: 6
            )
        }
        return TraceWaySharedRoute(
            shareID: shareID,
            routeName: name,
            createdAt: start,
            startedAt: start,
            endedAt: start.addingTimeInterval(40),
            distanceMeters: 800,
            durationSeconds: 40,
            quality: "fair",
            points: points
        )
    }
}
