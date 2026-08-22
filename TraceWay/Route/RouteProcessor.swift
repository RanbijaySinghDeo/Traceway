//
//  RouteProcessor.swift
//  TraceWay
//

import CoreLocation
import Foundation

/// Filters raw GPS fixes before they become part of the recorded path.
/// Intentionally light: preserve narrow-road fidelity; never snap to roads.
struct RouteProcessor: Sendable {
    var configuration: RouteProcessingConfiguration
    private(set) var lastAccepted: LocationPoint?

    init(configuration: RouteProcessingConfiguration = .default) {
        self.configuration = configuration
    }

    mutating func reset() {
        lastAccepted = nil
    }

    mutating func evaluate(
        _ candidate: LocationPoint,
        now: Date = .now
    ) -> RoutePointEvaluation {
        if let accuracyRejection = evaluateAccuracy(candidate) {
            return .reject(accuracyRejection)
        }

        if candidate.timestamp > now.addingTimeInterval(5) {
            return .reject(.invalidTimestamp)
        }

        let age = now.timeIntervalSince(candidate.timestamp)
        if age > configuration.maximumLocationAge {
            return .reject(.stale)
        }

        guard let previous = lastAccepted else {
            lastAccepted = candidate
            return .accept(candidate)
        }

        if candidate.timestamp < previous.timestamp.addingTimeInterval(-configuration.maximumTimestampRewind) {
            return .reject(.invalidTimestamp)
        }

        let distance = previous.distance(to: candidate)
        if distance < configuration.duplicateDistanceMeters {
            return .reject(.duplicate)
        }

        let timeDelta = candidate.timestamp.timeIntervalSince(previous.timestamp)
        if timeDelta > 0 {
            let impliedSpeed = distance / timeDelta
            if impliedSpeed > configuration.maximumImpliedSpeedMetersPerSecond {
                return .reject(.impossibleJump)
            }
        } else if distance >= configuration.minimumMovementMeters {
            // Same/near timestamp with meaningful movement is suspicious.
            return .reject(.impossibleJump)
        }

        if distance < configuration.minimumMovementMeters {
            return .reject(.insufficientMovement)
        }

        lastAccepted = candidate
        return .accept(candidate)
    }

    private func evaluateAccuracy(_ candidate: LocationPoint) -> RoutePointRejectionReason? {
        let accuracy = candidate.horizontalAccuracy
        if accuracy < 0 {
            return .invalidAccuracy
        }
        if accuracy > configuration.maximumAcceptableAccuracyMeters {
            return .poorAccuracy
        }
        return nil
    }
}
