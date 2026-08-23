//
//  RouteSource.swift
//  TraceWay
//

import Foundation

/// Origin of a persisted route. Existing pre-sharing routes default to `.recorded`.
enum RouteSource: String, Codable, Sendable, CaseIterable {
    /// Captured on this device via TraceWay recording.
    case recorded
    /// Imported from a TraceWaySharedRoute (e.g. QR scan).
    case received
}
