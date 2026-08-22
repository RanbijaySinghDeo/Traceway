//
//  RecordingStateMachineTests.swift
//  TraceWayTests
//

import XCTest
@testable import TraceWay

final class RecordingStateMachineTests: XCTestCase {
    func testIdleToRecording() throws {
        var machine = RecordingStateMachine()
        try machine.transition(to: .recording)
        XCTAssertEqual(machine.state, .recording)
    }

    func testRecordingPauseResumeStop() throws {
        var machine = RecordingStateMachine(state: .recording)

        try machine.transition(to: .paused)
        XCTAssertEqual(machine.state, .paused)
        XCTAssertFalse(machine.state.acceptsLocationUpdates)

        try machine.transition(to: .recording)
        XCTAssertTrue(machine.state.acceptsLocationUpdates)

        try machine.transition(to: .stopping)
        try machine.transition(to: .idle)
        XCTAssertEqual(machine.state, .idle)
    }

    func testInvalidTransitionThrows() {
        var machine = RecordingStateMachine(state: .idle)
        XCTAssertThrowsError(try machine.transition(to: .paused)) { error in
            guard case RecordingStateTransitionError.invalidTransition = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPausedCanStop() throws {
        var machine = RecordingStateMachine(state: .paused)
        try machine.transition(to: .stopping)
        XCTAssertEqual(machine.state, .stopping)
    }
}
