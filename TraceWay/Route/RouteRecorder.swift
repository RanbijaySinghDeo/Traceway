//
//  RouteRecorder.swift
//  TraceWay
//

import Foundation

struct RecordingSnapshot: Sendable, Equatable, Identifiable {
    let id: UUID
    var state: RecordingState
    var points: [LocationPoint]
    var distanceMeters: Double
    var durationSeconds: TimeInterval
    var startedAt: Date?
    var endedAt: Date?
    var quality: RouteQualitySummary

    init(
        id: UUID = UUID(),
        state: RecordingState,
        points: [LocationPoint],
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        startedAt: Date?,
        endedAt: Date?,
        quality: RouteQualitySummary
    ) {
        self.id = id
        self.state = state
        self.points = points
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.quality = quality
    }
}

enum RouteRecorderError: Error, Equatable, LocalizedError {
    case invalidState(RecordingStateTransitionError)
    case noPointsRecorded

    var errorDescription: String? {
        switch self {
        case let .invalidState(error):
            error.errorDescription
        case .noPointsRecorded:
            "No GPS points were recorded."
        }
    }
}

/// Owns recording lifecycle and accepted track points. Does not talk to Core Location or SwiftData.
@MainActor
final class RouteRecorder {
    private var stateMachine = RecordingStateMachine()
    private var processor: RouteProcessor

    private(set) var points: [LocationPoint] = []
    private(set) var distanceMeters: Double = 0
    private(set) var startedAt: Date?
    private(set) var endedAt: Date?

    private var accumulatedActiveDuration: TimeInterval = 0
    private var activeSegmentStartedAt: Date?

    var state: RecordingState { stateMachine.state }

    var durationSeconds: TimeInterval {
        var total = accumulatedActiveDuration
        if state == .recording, let segmentStart = activeSegmentStartedAt {
            total += Date.now.timeIntervalSince(segmentStart)
        }
        return max(0, total)
    }

    init(processor: RouteProcessor = RouteProcessor()) {
        self.processor = processor
    }

    func start(at date: Date = .now) throws {
        try transition(to: .recording)
        resetSessionMetrics()
        startedAt = date
        activeSegmentStartedAt = date
        processor.reset()
    }

    func pause(at date: Date = .now) throws {
        try transition(to: .paused)
        closeActiveSegment(at: date)
    }

    func resume(at date: Date = .now) throws {
        try transition(to: .recording)
        activeSegmentStartedAt = date
        // Do not carry pause gap into the path; next accepted point continues from last accepted.
    }

    @discardableResult
    func stop(at date: Date = .now) throws -> RecordingSnapshot {
        switch state {
        case .recording, .paused:
            break
        case .idle, .stopping:
            throw RouteRecorderError.invalidState(
                .invalidTransition(from: state, to: .stopping)
            )
        }

        if state == .recording {
            closeActiveSegment(at: date)
        }

        try transition(to: .stopping)
        endedAt = date

        let snapshot = makeSnapshot()
        try transition(to: .idle)
        return snapshot
    }

    /// Ingest a location only while actively recording. Paused periods never add points.
    @discardableResult
    func ingest(_ candidate: LocationPoint, now: Date = .now) -> RoutePointEvaluation {
        guard state.acceptsLocationUpdates else {
            return .reject(.notRecording)
        }

        let evaluation = processor.evaluate(candidate, now: now)
        if case let .accept(point) = evaluation {
            if let last = points.last {
                distanceMeters += DistanceCalculator.distance(from: last, to: point)
            }
            points.append(point)
        }
        return evaluation
    }

    func discard() throws {
        if state == .recording {
            closeActiveSegment(at: .now)
        }
        if state == .recording || state == .paused {
            try transition(to: .stopping)
        }
        if state == .stopping {
            try transition(to: .idle)
        }
        resetSessionMetrics()
        processor.reset()
    }

    func makeSnapshot() -> RecordingSnapshot {
        RecordingSnapshot(
            state: state,
            points: points,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            startedAt: startedAt,
            endedAt: endedAt,
            quality: points.summarizingQuality(
                thresholds: processor.configuration.qualityThresholds
            )
        )
    }

    private func transition(to newState: RecordingState) throws {
        do {
            try stateMachine.transition(to: newState)
        } catch let error as RecordingStateTransitionError {
            throw RouteRecorderError.invalidState(error)
        }
    }

    private func closeActiveSegment(at date: Date) {
        if let segmentStart = activeSegmentStartedAt {
            accumulatedActiveDuration += date.timeIntervalSince(segmentStart)
        }
        activeSegmentStartedAt = nil
    }

    private func resetSessionMetrics() {
        points = []
        distanceMeters = 0
        startedAt = nil
        endedAt = nil
        accumulatedActiveDuration = 0
        activeSegmentStartedAt = nil
    }
}
