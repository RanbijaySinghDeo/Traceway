//
//  RouteQRScannerView.swift
//  TraceWay
//

import SwiftUI

struct RouteQRScannerView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    /// Called after the user chooses Open Route from the confirmation sheet.
    var onOpenRoute: (Route) -> Void

    @State private var viewModel: RouteQRScannerViewModel?
    @State private var confirmationRoute: Route?
    @State private var confirmationIsDuplicate = false
    @State private var showConfirmation = false

    var body: some View {
        Group {
            if let viewModel {
                RouteQRScannerContent(
                    viewModel: viewModel,
                    showConfirmation: $showConfirmation,
                    confirmationRoute: $confirmationRoute,
                    confirmationIsDuplicate: $confirmationIsDuplicate,
                    onOpenRoute: { route in
                        dismiss()
                        // Allow dismiss animation to settle before pushing detail.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onOpenRoute(route)
                        }
                    },
                    onDone: {
                        dismiss()
                    }
                )
            } else {
                ProgressView()
                    .tint(TraceWayTheme.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = RouteQRScannerViewModel(routeStore: dependencies.routeStore)
            }
            viewModel?.onAppear()
        }
        .onDisappear {
            viewModel?.onDisappear()
        }
    }
}

private struct RouteQRScannerContent: View {
    @Bindable var viewModel: RouteQRScannerViewModel
    @Binding var showConfirmation: Bool
    @Binding var confirmationRoute: Route?
    @Binding var confirmationIsDuplicate: Bool
    let onOpenRoute: (Route) -> Void
    let onDone: () -> Void

    /// Equatable token so we can observe phase transitions without requiring Route: Equatable.
    private var phaseToken: String {
        switch viewModel.phase {
        case .checkingPermission: "checking"
        case .needsPermissionPrompt: "prompt"
        case .permissionDenied: "denied"
        case .ready: "ready"
        case .processing: "processing"
        case let .invalidQR(title, _): "invalid:\(title)"
        case let .imported(route): "imported:\(route.id.uuidString)"
        case let .alreadyExists(route): "exists:\(route.id.uuidString)"
        case let .failed(title, _): "failed:\(title)"
        }
    }

    var body: some View {
        ZStack {
            TraceWayTheme.background.ignoresSafeArea()

            switch viewModel.phase {
            case .checkingPermission:
                ProgressView()
                    .tint(TraceWayTheme.accent)

            case .needsPermissionPrompt:
                permissionPrompt

            case .permissionDenied:
                permissionDenied

            case .ready, .processing, .invalidQR, .failed, .imported, .alreadyExists:
                cameraLayer
            }
        }
        .navigationTitle("Scan Route QR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TraceWayTheme.surface.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: phaseToken) { _, _ in
            switch viewModel.phase {
            case let .imported(route):
                confirmationRoute = route
                confirmationIsDuplicate = false
                showConfirmation = true
            case let .alreadyExists(route):
                confirmationRoute = route
                confirmationIsDuplicate = true
                showConfirmation = true
            default:
                break
            }
        }
        .alert(
            alertTitle,
            isPresented: Binding(
                get: {
                    if case .invalidQR = viewModel.phase { return true }
                    if case .failed = viewModel.phase { return true }
                    return false
                },
                set: { presented in
                    if !presented {
                        viewModel.resumeScanning()
                    }
                }
            )
        ) {
            Button("Try Again", role: .cancel) {
                viewModel.resumeScanning()
            }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showConfirmation) {
            if let route = confirmationRoute {
                RouteReceivedView(
                    route: route,
                    isDuplicate: confirmationIsDuplicate,
                    onOpenRoute: {
                        showConfirmation = false
                        onOpenRoute(route)
                    },
                    onDone: {
                        showConfirmation = false
                        onDone()
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var cameraLayer: some View {
        ZStack {
            CameraPreviewView(session: viewModel.previewSession)
                .ignoresSafeArea()
                .accessibilityLabel("QR code scanner")

            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(TraceWayTheme.accent.opacity(0.9), lineWidth: 3)
                    .frame(width: 240, height: 240)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.05))
                    )
                Spacer()

                VStack(spacing: 6) {
                    if case .processing = viewModel.phase {
                        ProgressView()
                            .tint(TraceWayTheme.accent)
                        Text("Saving route…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TraceWayTheme.textPrimary)
                    } else {
                        Text("Scan a TraceWay route QR code")
                            .font(.headline)
                            .foregroundStyle(TraceWayTheme.textPrimary)
                        Text("Point your camera at the QR code shared with you.")
                            .font(.footnote)
                            .foregroundStyle(TraceWayTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(TraceWayTheme.surface.opacity(0.92))
            }
        }
    }

    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(TraceWayTheme.accent)
            Text("Camera Access")
                .font(.title3.weight(.semibold))
                .foregroundStyle(TraceWayTheme.textPrimary)
            Text("TraceWay uses the camera to scan route QR codes shared with you.")
                .font(.subheadline)
                .foregroundStyle(TraceWayTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Continue") {
                viewModel.requestPermission()
            }
            .buttonStyle(TraceWayPrimaryButtonStyle())
            .padding(.horizontal, 24)
            .accessibilityLabel("Continue")
        }
    }

    private var permissionDenied: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(TraceWayTheme.warning)
            Text("Camera Access Required")
                .font(.title3.weight(.semibold))
                .foregroundStyle(TraceWayTheme.textPrimary)
            Text("TraceWay needs camera access to scan route QR codes.")
                .font(.subheadline)
                .foregroundStyle(TraceWayTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Open Settings") {
                viewModel.openSettings()
            }
            .buttonStyle(TraceWayPrimaryButtonStyle())
            .padding(.horizontal, 24)
            .accessibilityLabel("Open Settings")

            Button("Cancel", action: onDone)
                .buttonStyle(TraceWaySecondaryButtonStyle())
                .padding(.horizontal, 24)
                .accessibilityLabel("Cancel")
        }
    }

    private var alertTitle: String {
        switch viewModel.phase {
        case let .invalidQR(title, _), let .failed(title, _):
            title
        default:
            "Something Went Wrong"
        }
    }

    private var alertMessage: String {
        switch viewModel.phase {
        case let .invalidQR(_, message), let .failed(_, message):
            message
        default:
            ""
        }
    }
}
