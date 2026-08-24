//
//  RouteDetailView.swift
//  TraceWay
//

import CoreLocation
import SwiftUI

struct RouteDetailView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let route: Route
    @State private var viewModel: RouteDetailViewModel?
    @State private var isSharePresented = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let viewModel {
                RouteDetailContent(
                    viewModel: viewModel,
                    isSharePresented: $isSharePresented,
                    confirmDelete: $confirmDelete,
                    onDeleted: { dismiss() }
                )
            } else {
                ProgressView()
                    .tint(TraceWayTheme.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = RouteDetailViewModel(
                    route: route,
                    routeStore: dependencies.routeStore,
                    exporter: dependencies.routeExporter
                )
            }
        }
    }
}

private struct RouteDetailContent: View {
    @Bindable var viewModel: RouteDetailViewModel
    @Binding var isSharePresented: Bool
    @Binding var confirmDelete: Bool
    let onDeleted: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            RouteMapView(
                userCoordinate: nil,
                routeCoordinates: viewModel.coordinates,
                showsUserLocation: false,
                followUser: false,
                fitToRoute: true,
                bottomContentInset: 280
            )
            .ignoresSafeArea(edges: .bottom)

            // Soft fade so the overlay card sits cleanly on the map.
            LinearGradient(
                colors: [
                    .clear,
                    TraceWayTheme.background.opacity(0.55),
                    TraceWayTheme.background.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                overlayCard

                HStack(spacing: 10) {
                    NavigationLink {
                        ShowRouteQRView(route: viewModel.route)
                    } label: {
                        Label("Show QR", systemImage: "qrcode")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TraceWayPrimaryButtonStyle())
                    .accessibilityLabel("Show QR Code")

                    Button {
                        viewModel.prepareShareGPX()
                        isSharePresented = viewModel.shareURL != nil
                    } label: {
                        Label("GPX", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TraceWaySecondaryButtonStyle())
                    .accessibilityLabel("Export GPX")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(TraceWayTheme.background.ignoresSafeArea())
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TraceWayTheme.surface.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete route")
            }
        }
        .sheet(isPresented: $isSharePresented) {
            if let url = viewModel.shareURL {
                ShareSheet(fileURL: url, routeName: viewModel.routeName)
                    .presentationDetents([.medium, .large])
            }
        }
        .confirmationDialog(
            "Delete this route?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Route", role: .destructive) {
                viewModel.deleteRoute()
                if viewModel.didDelete {
                    onDeleted()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var overlayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isEditingName {
                TextField("Route name", text: $viewModel.routeName)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(TraceWayTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(TraceWayTheme.textPrimary)
                    .textInputAutocapitalization(.words)

                HStack {
                    Button("Cancel", action: viewModel.cancelEditName)
                        .foregroundStyle(TraceWayTheme.textSecondary)
                    Spacer()
                    Button("Save", action: viewModel.saveName)
                        .fontWeight(.semibold)
                        .foregroundStyle(TraceWayTheme.textOnAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(TraceWayTheme.accent, in: Capsule())
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.routeName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(TraceWayTheme.textPrimary)
                            .lineLimit(2)

                        Text(TraceWayFormatters.dateTime(viewModel.route.startedAt))
                            .font(.caption)
                            .foregroundStyle(TraceWayTheme.textSecondary)
                    }

                    Spacer(minLength: 8)

                    Button {
                        viewModel.isEditingName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TraceWayTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(TraceWayTheme.accent.opacity(0.14), in: Circle())
                    }
                    .accessibilityLabel("Edit route name")
                }
            }

            HStack(spacing: 0) {
                metricChip(
                    icon: "road.lanes",
                    value: TraceWayFormatters.distance(viewModel.route.distanceMeters)
                )
                metricDivider
                metricChip(
                    icon: "clock",
                    value: TraceWayFormatters.duration(viewModel.route.durationSeconds)
                )
                metricDivider
                metricChip(
                    icon: "calendar",
                    value: TraceWayFormatters.date(viewModel.route.startedAt)
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(TraceWayTheme.surface.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
        )
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 36)
    }

    private func metricChip(icon: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TraceWayTheme.accent)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TraceWayTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
