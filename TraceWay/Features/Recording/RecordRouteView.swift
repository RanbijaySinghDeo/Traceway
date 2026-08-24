//
//  RecordRouteView.swift
//  TraceWay
//

import SwiftUI

struct RecordRouteView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: RecordRouteViewModel?

    var body: some View {
        Group {
            if let viewModel {
                RecordRouteContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .tint(TraceWayTheme.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = RecordRouteViewModel(
                    locationService: dependencies.locationService,
                    routeStore: dependencies.routeStore,
                    routeExporter: dependencies.routeExporter,
                    qualityThresholds: dependencies.gpsQualityThresholds
                )
            }
            viewModel?.onAppear()
        }
        .onDisappear {
            viewModel?.onDisappear()
        }
    }
}

private struct RecordRouteContent: View {
    @Bindable var viewModel: RecordRouteViewModel

    var body: some View {
        ZStack {
            RouteMapView(
                userCoordinate: viewModel.latestLocation?.coordinate,
                routeCoordinates: viewModel.routeCoordinates,
                showsUserLocation: viewModel.authorizationState.canShowUserLocation && !viewModel.showsCompletionModal,
                followUser: viewModel.recordingState == .recording || viewModel.recordingState == .idle,
                fitToRoute: viewModel.recordingState == .paused || viewModel.showsCompletionModal,
                bottomContentInset: 220,
                followZoomMeters: viewModel.recordingState == .recording ? 380 : 280
            )
            .ignoresSafeArea(edges: .bottom)

            if viewModel.showsCompletionModal, let snapshot = viewModel.pendingSaveSnapshot {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)

                RecordingCompletionModal(
                    snapshot: snapshot,
                    routeName: $viewModel.routeNameDraft,
                    isSaving: viewModel.isSaving,
                    onClose: { viewModel.closeCompletionModal() },
                    onShare: { viewModel.presentShareOptions() }
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 12) {
                    if !viewModel.authorizationState.canRecordRoute {
                        LocationPermissionView(
                            state: viewModel.authorizationState,
                            onRequestAccess: viewModel.requestAccess,
                            onOpenSettings: viewModel.openSettings
                        )
                    }

                    statusCard
                    controls
                }
                .padding()
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.showsCompletionModal)
        .navigationTitle("Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TraceWayTheme.surface.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert(
            "Couldn’t continue",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog(
            "Share route",
            isPresented: $viewModel.isShareOptionsPresented,
            titleVisibility: .visible
        ) {
            Button("Share GPX file (Mail, Files…)") {
                viewModel.prepareAndPresentGPXShare()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Export a GPX file of the exact path. To share with another TraceWay user, open the route in Routes and tap Show QR Code.")
        }
        .sheet(isPresented: $viewModel.isSharePresented) {
            if let url = viewModel.shareFileURL {
                ShareSheet(fileURL: url, routeName: viewModel.routeNameDraft)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TraceWayTheme.textSecondary)
                Spacer()
                if viewModel.recordingState == .recording {
                    RecordingPulseDot()
                }
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TraceWayFormatters.distance(viewModel.distanceMeters))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(TraceWayTheme.textPrimary)
                        .monospacedDigit()
                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(TraceWayTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(TraceWayFormatters.duration(viewModel.durationSeconds))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(TraceWayTheme.accent)
                        .monospacedDigit()
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(TraceWayTheme.textSecondary)
                }
            }

            GPSQualityBadge(
                quality: viewModel.gpsQuality,
                accuracyMeters: viewModel.latestLocation?.horizontalAccuracy
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .traceWayCard()
    }

    private var statusTitle: String {
        switch viewModel.recordingState {
        case .idle:
            "Current location"
        case .recording:
            "Recording"
        case .paused:
            "Recording paused"
        case .stopping:
            "Saving…"
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch viewModel.recordingState {
        case .idle:
            Button {
                viewModel.startRecording()
            } label: {
                Label("Start Recording", systemImage: "record.circle.fill")
            }
            .buttonStyle(TraceWayPrimaryButtonStyle())
            .disabled(!viewModel.canStart)

        case .recording:
            HStack(spacing: 12) {
                Button {
                    viewModel.pauseRecording()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(TraceWaySecondaryButtonStyle())

                Button {
                    viewModel.stopRecording()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(TraceWayPrimaryButtonStyle(isDestructive: true))
            }

        case .paused:
            HStack(spacing: 12) {
                Button {
                    viewModel.resumeRecording()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(TraceWayPrimaryButtonStyle())

                Button {
                    viewModel.stopRecording()
                } label: {
                    Label("Stop & Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(TraceWaySecondaryButtonStyle())
            }

        case .stopping:
            ProgressView("Finishing…")
                .tint(TraceWayTheme.accent)
                .foregroundStyle(TraceWayTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding()
                .traceWayCard()
        }
    }
}

private struct RecordingCompletionModal: View {
    let snapshot: RecordingSnapshot
    @Binding var routeName: String
    let isSaving: Bool
    let onClose: () -> Void
    let onShare: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Route complete")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TraceWayTheme.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(TraceWayTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(TraceWayTheme.surfaceElevated, in: Circle())
                }
                .accessibilityLabel("Close")
                .disabled(isSaving)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 16) {
                TextField("Route name", text: $routeName)
                    .focused($isNameFocused)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(TraceWayTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(TraceWayTheme.textPrimary)

                HStack(spacing: 12) {
                    metricTile(
                        title: "Distance",
                        value: TraceWayFormatters.distance(snapshot.distanceMeters),
                        accent: false
                    )
                    metricTile(
                        title: "Duration",
                        value: TraceWayFormatters.duration(snapshot.durationSeconds),
                        accent: true
                    )
                }

                VStack(spacing: 10) {
                    detailRow("Points", "\(snapshot.points.count)")
                    detailRow("GPS quality", snapshot.quality.displayTitle)
                    if let start = snapshot.startedAt {
                        detailRow("Started", TraceWayFormatters.dateTime(start))
                    }
                    if let end = snapshot.endedAt {
                        detailRow("Ended", TraceWayFormatters.dateTime(end))
                    }
                }
                .padding(14)
                .background(TraceWayTheme.surfaceElevated.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(TraceWayPrimaryButtonStyle())
                .disabled(isSaving)
            }
            .padding(18)
        }
        .frame(maxWidth: 480)
        .traceWayCard(cornerRadius: 22)
        .onAppear {
            isNameFocused = false
        }
    }

    private func metricTile(title: String, value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(TraceWayTheme.textSecondary)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(accent ? TraceWayTheme.accent : TraceWayTheme.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TraceWayTheme.surfaceElevated.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(TraceWayTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(TraceWayTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct RecordingPulseDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(TraceWayTheme.accent)
            .frame(width: 8, height: 8)
            .shadow(color: TraceWayTheme.accent.opacity(0.8), radius: pulse ? 8 : 3)
            .scaleEffect(pulse ? 1.2 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

#Preview {
    NavigationStack {
        RecordRouteView()
    }
    .environment(AppDependencies.preview())
    .preferredColorScheme(.dark)
}
