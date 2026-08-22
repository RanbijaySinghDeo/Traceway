//
//  RootView.swift
//  TraceWay
//

import SwiftUI

/// Top-level navigation shell.
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                RecordRouteView()
            }
            .tabItem {
                Label("Record", systemImage: "record.circle")
            }

            NavigationStack {
                RoutesListView()
            }
            .tabItem {
                Label("My Routes", systemImage: "list.bullet")
            }
        }
        .toolbarBackground(TraceWayTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(TraceWayTheme.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    RootView()
        .environment(AppDependencies.preview())
        .preferredColorScheme(.dark)
}
