//
//  RouteExporterTests.swift
//  TraceWayTests
//

import CoreLocation
import XCTest
@testable import TraceWay

final class RouteExporterTests: XCTestCase {
    private let exporter = RouteExporter()
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testGPXGenerationStructureAndPoints() throws {
        let points = [
            LocationPoint(
                coordinate: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
                timestamp: createdAt,
                horizontalAccuracy: 5,
                speed: 3,
                course: 10,
                altitude: 920
            ),
            LocationPoint(
                coordinate: CLLocationCoordinate2D(latitude: 12.9720, longitude: 77.5950),
                timestamp: createdAt.addingTimeInterval(30),
                horizontalAccuracy: 6,
                speed: 4,
                course: 15,
                altitude: 921
            )
        ]

        let data = try exporter.makeGPX(name: "Home → Office", points: points, createdAt: createdAt)
        let xml = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(xml.contains("<?xml"))
        XCTAssertTrue(xml.contains("<gpx"))
        XCTAssertTrue(xml.contains("<trk>"))
        XCTAssertTrue(xml.contains("<trkseg>"))
        XCTAssertTrue(xml.contains("lat=\"12.9716\""))
        XCTAssertTrue(xml.contains("lon=\"77.5946\""))
        XCTAssertTrue(xml.contains("<ele>920.0</ele>") || xml.contains("<ele>920</ele>"))
        XCTAssertEqual(xml.components(separatedBy: "<trkpt ").count - 1, 2)
        XCTAssertTrue(xml.contains("<time>"))
    }

    func testEmptyRouteThrows() {
        XCTAssertThrowsError(try exporter.makeGPX(name: "Empty", points: [], createdAt: createdAt)) { error in
            XCTAssertEqual(error as? RouteExporterError, .emptyRoute)
        }
    }
}
