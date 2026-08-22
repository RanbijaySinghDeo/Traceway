//
//  RouteQuality+Display.swift
//  TraceWay
//

import SwiftUI

extension RouteQualitySummary {
    var displayTitle: String {
        switch self {
        case .excellent: "Excellent"
        case .fair: "Fair"
        case .poor: "Poor"
        case .mixed: "Mixed"
        case .unknown: "Unknown"
        }
    }
}
