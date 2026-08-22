//
//  TraceWayApp.swift
//  TraceWay
//

import SwiftUI
import SwiftData

@main
struct TraceWayApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
                .preferredColorScheme(.dark)
                .tint(TraceWayTheme.accent)
        }
        .modelContainer(dependencies.modelContainer)
    }
}
