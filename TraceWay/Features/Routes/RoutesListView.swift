//
//  RoutesListView.swift
//  TraceWay
//

import SwiftUI

struct RoutesListView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: RoutesListViewModel?
    @State private var routeToOpen: Route?

    var body: some View {
        Group {
            if let viewModel {
                RoutesListContent(
                    viewModel: viewModel,
                    routeToOpen: $routeToOpen
                )
            } else {
                ProgressView()
                    .tint(TraceWayTheme.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = RoutesListViewModel(routeStore: dependencies.routeStore)
            }
            viewModel?.load()
        }
        .navigationDestination(isPresented: Binding(
            get: { routeToOpen != nil },
            set: { if !$0 { routeToOpen = nil } }
        )) {
            if let routeToOpen {
                RouteDetailView(route: routeToOpen)
            }
        }
    }
}

private struct RoutesListContent: View {
    @Bindable var viewModel: RoutesListViewModel
    @Binding var routeToOpen: Route?

    var body: some View {
        Group {
            switch viewModel.segment {
            case .myRoutes:
                myRoutesBody
            case .received:
                receivedBody
            }
        }
        .traceWayScreenBackground()
        .navigationTitle("Routes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TraceWayTheme.surface.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if viewModel.segment == .received, !viewModel.routes.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RouteQRScannerView(onOpenRoute: { route in
                            routeToOpen = route
                        })
                        .onDisappear {
                            viewModel.load()
                        }
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(TraceWayTheme.accent)
                            .frame(width: 34, height: 34)
                            .background(TraceWayTheme.accent.opacity(0.14), in: Circle())
                    }
                    .accessibilityLabel("Scan QR")
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Route Type", selection: Binding(
                get: { viewModel.segment },
                set: { viewModel.selectSegment($0) }
            )) {
                ForEach(RoutesListSegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(TraceWayTheme.background.opacity(0.95))
        }
        .refreshable {
            viewModel.load()
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
        .onChange(of: routeToOpen?.id) { _, newValue in
            if newValue != nil {
                viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var myRoutesBody: some View {
        if viewModel.routes.isEmpty {
            ContentUnavailableView {
                Label("No routes yet", systemImage: "map")
            } description: {
                Text("Record a route to see it here.")
                    .foregroundStyle(TraceWayTheme.textSecondary)
            }
            .foregroundStyle(TraceWayTheme.textPrimary)
            .symbolRenderingMode(.hierarchical)
            .tint(TraceWayTheme.accent)
        } else {
            routeList
        }
    }

    @ViewBuilder
    private var receivedBody: some View {
        if viewModel.routes.isEmpty {
            receivedEmptyState
        } else {
            routeList
        }
    }

    private var receivedEmptyState: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(TraceWayTheme.accent.opacity(0.12))
                    .frame(width: 110, height: 110)
                Circle()
                    .strokeBorder(TraceWayTheme.accent.opacity(0.22), lineWidth: 1)
                    .frame(width: 110, height: 110)
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(TraceWayTheme.accent)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("No Received Routes")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(TraceWayTheme.textPrimary)

                Text("Scan a TraceWay QR to save a friend’s exact GPS path here.")
                    .font(.subheadline)
                    .foregroundStyle(TraceWayTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            NavigationLink {
                RouteQRScannerView(onOpenRoute: { route in
                    routeToOpen = route
                })
                .onDisappear {
                    viewModel.load()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.body.weight(.semibold))
                    Text("Scan QR Code")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(TraceWayTheme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: TraceWayTheme.controlCornerRadius, style: .continuous)
                        .fill(TraceWayTheme.accent)
                        .shadow(color: TraceWayTheme.accent.opacity(0.35), radius: 16, y: 6)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .accessibilityLabel("Scan QR Code")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var routeList: some View {
        List {
            ForEach(viewModel.routes, id: \.id) { route in
                NavigationLink {
                    RouteDetailView(route: route)
                } label: {
                    RouteRowView(route: route)
                }
                .listRowBackground(TraceWayTheme.surface)
                .listRowSeparatorTint(Color.white.opacity(0.08))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.delete(viewModel.routes[index])
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

private struct RouteRowView: View {
    let route: Route

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(TraceWayTheme.accent.opacity(0.18))
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.headline)
                    .foregroundStyle(TraceWayTheme.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(TraceWayTheme.accent)

                Text(TraceWayFormatters.date(route.createdAt))
                    .font(.caption)
                    .foregroundStyle(TraceWayTheme.textSecondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var subtitle: String {
        "\(TraceWayFormatters.distance(route.distanceMeters)) • \(TraceWayFormatters.duration(route.durationSeconds))"
    }
}

#Preview {
    NavigationStack {
        RoutesListView()
    }
    .environment(AppDependencies.preview())
    .preferredColorScheme(.dark)
}
