//
//  RouteRecorderTests.swift
//  TraceWayTests
//

import CoreLocation
import XCTest
@testable import TraceWay

@MainActor
final class RouteRecorderTests: XCTestCase {
    private var recorder: RouteRecorder!
    private let start = Date(timeIntervalSince1970: 2_000_000_000)

    override func setUp() {
        recorder = RouteRecorder()
    }

    func testStartPauseResumeStopTransitions() throws {
        XCTAssertEqual(recorder.state, .idle)
        try recorder.start(at: start)
        XCTAssertEqual(recorder.state, .recording)

        try recorder.pause(at: start.addingTimeInterval(10))
        XCTAssertEqual(recorder.state, .paused)

        try recorder.resume(at: start.addingTimeInterval(20))
        XCTAssertEqual(recorder.state, .recording)

        let snapshot = try recorder.stop(at: start.addingTimeInterval(30))
        XCTAssertEqual(recorder.state, .idle)
        XCTAssertEqual(snapshot.state, .stopping)
    }

    func testPointsCollectedOnlyWhileRecording() throws {
        try recorder.start(at: start)

        let p1 = point(lat: 28.61, lon: 77.20, offset: 0)
        let p2 = point(lat: 28.61005, lon: 77.20005, offset: 5)
        XCTAssertAccept(recorder.ingest(p1, now: start))
        XCTAssertAccept(recorder.ingest(p2, now: start.addingTimeInterval(5)))
        XCTAssertEqual(recorder.points.count, 2)

        try recorder.pause(at: start.addingTimeInterval(6))
        let whilePaused = point(lat: 28.61010, lon: 77.20010, offset: 8)
        _ = recorder.ingest(whilePaused, now: start.addingTimeInterval(8))
        XCTAssertEqual(recorder.points.count, 2)

        try recorder.resume(at: start.addingTimeInterval(10))
        let afterResume = point(lat: 28.61020, lon: 77.20020, offset: 12)
        XCTAssertAccept(recorder.ingest(afterResume, now: start.addingTimeInterval(12)))
        XCTAssertEqual(recorder.points.count, 3)
    }

    func testInvalidTransitionThrows() {
        XCTAssertThrowsError(try recorder.pause())
        XCTAssertThrowsError(try recorder.stop())
    }

    private func point(lat: Double, lon: Double, offset: TimeInterval) -> LocationPoint {
        LocationPoint(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            timestamp: start.addingTimeInterval(offset),
            horizontalAccuracy: 6,
            speed: 4,
            course: 45,
            altitude: 210
        )
    }

    private func XCTAssertAccept(
        _ evaluation: RoutePointEvaluation,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .accept = evaluation else {
            XCTFail("Expected accept, got \(evaluation)", file: file, line: line)
            return
        }
    }
}
