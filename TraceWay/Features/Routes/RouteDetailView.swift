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
    @State private var isShareOptionsPresented = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let viewModel {
                RouteDetailContent(
                    viewModel: viewModel,
                    isSharePresented: $isSharePresented,
                    isShareOptionsPresented: $isShareOptionsPresented,
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
    @Binding var isShareOptionsPresented: Bool
    @Binding var confirmDelete: Bool
    let onDeleted: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RouteMapView(
                    userCoordinate: nil,
                    routeCoordinates: viewModel.coordinates,
                    showsUserLocation: false,
                    followUser: false,
                    fitToRoute: true
                )
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: TraceWayTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TraceWayTheme.cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 12) {
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
                            Button("Save Name", action: viewModel.saveName)
                                .fontWeight(.semibold)
                                .foregroundStyle(TraceWayTheme.textOnAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(TraceWayTheme.accent, in: Capsule())
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline) {
                            Text(viewModel.routeName)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(TraceWayTheme.textPrimary)
                            Spacer()
                            Button {
                                viewModel.isEditingName = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(TraceWayTheme.accent)
                                    .padding(8)
                                    .background(TraceWayTheme.surfaceElevated, in: Circle())
                            }
                            .accessibilityLabel("Edit route name")
                        }
                    }

                    metricRow(title: "Distance", value: TraceWayFormatters.distance(viewModel.route.distanceMeters), emphasize: true)
                    metricRow(title: "Duration", value: TraceWayFormatters.duration(viewModel.route.durationSeconds), emphasize: true)
                    metricRow(title: "Recorded", value: TraceWayFormatters.dateTime(viewModel.route.startedAt))
                    metricRow(title: "GPS quality", value: viewModel.route.quality.displayTitle)
                    metricRow(title: "Points", value: "\(viewModel.route.orderedPoints.count)")

                    if let start = viewModel.startCoordinate {
                        metricRow(
                            title: "Start",
                            value: String(format: "%.5f, %.5f", start.latitude, start.longitude)
                        )
                    }
                    if let end = viewModel.endCoordinate {
                        metricRow(
                            title: "End",
                            value: String(format: "%.5f, %.5f", end.latitude, end.longitude)
                        )
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .traceWayCard()
            }
            .padding()
        }
        .traceWayScreenBackground()
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TraceWayTheme.surface.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShareOptionsPresented = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete route")
            }
        }
        .confirmationDialog(
            "Share route",
            isPresented: $isShareOptionsPresented,
            titleVisibility: .visible
        ) {
            Button("WhatsApp (location link)") {
                viewModel.shareViaWhatsApp()
            }
            Button("Share GPX file (Mail, Files…)") {
                viewModel.prepareShareGPX()
                isSharePresented = viewModel.shareURL != nil
            }
            Button("Open in Apple Maps") {
                viewModel.openInAppleMaps()
            }
            Button("Open in Google Maps") {
                viewModel.openInGoogleMaps()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("WhatsApp gets a tappable Maps location link. Use GPX when you need the exact TraceWay path.")
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

    private func metricRow(title: String, value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(TraceWayTheme.textSecondary)
            Spacer()
            Text(value)
                .font(emphasize ? .body.weight(.semibold) : .body)
                .foregroundStyle(emphasize ? TraceWayTheme.accent : TraceWayTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
