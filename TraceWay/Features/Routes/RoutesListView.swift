//
//  RoutesListView.swift
//  TraceWay
//

import SwiftUI

struct RoutesListView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: RoutesListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                RoutesListContent(viewModel: viewModel)
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
    }
}

private struct RoutesListContent: View {
    @Bindable var viewModel: RoutesListViewModel

    var body: some View {
        Group {
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
        .traceWayScreenBackground()
        .navigationTitle("My Routes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TraceWayTheme.surface.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
