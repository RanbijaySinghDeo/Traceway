//
//  GPSQualityBadge.swift
//  TraceWay
//

import SwiftUI

struct GPSQualityBadge: View {
    let quality: GPSQuality
    let accuracyMeters: Double?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: 4)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TraceWayTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var color: Color {
        switch quality {
        case .excellent: TraceWayTheme.accent
        case .fair: TraceWayTheme.warning
        case .poor: TraceWayTheme.danger
        case .unknown: TraceWayTheme.textSecondary
        }
    }

    private var label: String {
        if let accuracyMeters {
            "GPS \(quality.displayTitle) \(TraceWayFormatters.accuracy(accuracyMeters))"
        } else {
            "GPS \(quality.displayTitle)"
        }
    }
}
