//
//  TraceWayTheme.swift
//  TraceWay
//

import SwiftUI

/// Eco-dark visual language inspired by navigation HUD aesthetics:
/// deep charcoal surfaces + vibrant emerald actions/route.
enum TraceWayTheme {
    /// Near-black charcoal with a cool cast.
    static let background = Color(red: 0.06, green: 0.08, blue: 0.10)

    /// Floating card / sheet surface.
    static let surface = Color(red: 0.10, green: 0.13, blue: 0.16)

    /// Elevated chip / icon button fill.
    static let surfaceElevated = Color(red: 0.14, green: 0.17, blue: 0.21)

    /// Racing emerald accent (primary actions + route).
    static let accent = Color(red: 0.24, green: 0.86, blue: 0.52)

    /// Slightly deeper green for pressed / secondary emphasis.
    static let accentDeep = Color(red: 0.16, green: 0.65, blue: 0.40)

    /// Soft glow under the recorded path.
    static let routeGlow = Color(red: 0.24, green: 0.86, blue: 0.52)

    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.70, green: 0.74, blue: 0.78)
    static let textOnAccent = Color(red: 0.05, green: 0.08, blue: 0.07)

    static let danger = Color(red: 0.95, green: 0.35, blue: 0.32)
    static let warning = Color(red: 0.98, green: 0.72, blue: 0.22)

    static let cornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 14
    static let routeLineWidth: CGFloat = 5
    static let routeGlowWidth: CGFloat = 12
}

// MARK: - Reusable chrome

struct TraceWayCardBackground: ViewModifier {
    var cornerRadius: CGFloat = TraceWayTheme.cornerRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(TraceWayTheme.surface.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            )
    }
}

struct TraceWayPrimaryButtonStyle: ButtonStyle {
    var isDestructive = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(isDestructive ? TraceWayTheme.textPrimary : TraceWayTheme.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: TraceWayTheme.controlCornerRadius, style: .continuous)
                    .fill(fillColor(configuration.isPressed))
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func fillColor(_ pressed: Bool) -> Color {
        if isDestructive {
            return pressed ? TraceWayTheme.danger.opacity(0.85) : TraceWayTheme.danger
        }
        return pressed ? TraceWayTheme.accentDeep : TraceWayTheme.accent
    }
}

struct TraceWaySecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(TraceWayTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: TraceWayTheme.controlCornerRadius, style: .continuous)
                    .fill(TraceWayTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: TraceWayTheme.controlCornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension View {
    func traceWayCard(cornerRadius: CGFloat = TraceWayTheme.cornerRadius) -> some View {
        modifier(TraceWayCardBackground(cornerRadius: cornerRadius))
    }

    func traceWayScreenBackground() -> some View {
        background(TraceWayTheme.background.ignoresSafeArea())
    }
}
