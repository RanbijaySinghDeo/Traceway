//
//  RecordingState.swift
//  TraceWay
//

import Foundation

/// Explicit recording lifecycle. Prefer this over scattered booleans.
enum RecordingState: String, Sendable, Equatable {
    case idle
    case recording
    case paused
    case stopping

    /// Whether new GPS points should be accepted into the active track.
    var acceptsLocationUpdates: Bool {
        self == .recording
    }

    /// Whether location hardware should remain active (recording or paused mid-session).
    var requiresActiveLocationSession: Bool {
        switch self {
        case .recording, .paused, .stopping:
            true
        case .idle:
            false
        }
    }
}

enum RecordingStateTransitionError: Error, Equatable, LocalizedError {
    case invalidTransition(from: RecordingState, to: RecordingState)

    var errorDescription: String? {
        switch self {
        case let .invalidTransition(from, to):
            "Invalid recording transition from \(from.rawValue) to \(to.rawValue)."
        }
    }
}

/// Guards recording lifecycle transitions in one place.
struct RecordingStateMachine: Sendable, Equatable {
    private(set) var state: RecordingState

    init(state: RecordingState = .idle) {
        self.state = state
    }

    mutating func transition(to newState: RecordingState) throws {
        guard Self.canTransition(from: state, to: newState) else {
            throw RecordingStateTransitionError.invalidTransition(from: state, to: newState)
        }
        state = newState
    }

    static func canTransition(from: RecordingState, to: RecordingState) -> Bool {
        switch (from, to) {
        case (.idle, .recording):
            true
        case (.recording, .paused), (.recording, .stopping):
            true
        case (.paused, .recording), (.paused, .stopping):
            true
        case (.stopping, .idle):
            true
        case let (same, other) where same == other:
            // Idempotent no-op transitions are not allowed; callers should check first.
            false
        default:
            false
        }
    }
}
