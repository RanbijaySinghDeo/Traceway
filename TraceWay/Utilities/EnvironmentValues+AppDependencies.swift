//
//  EnvironmentValues+AppDependencies.swift
//  TraceWay
//

import SwiftUI

private struct AppDependenciesKey: EnvironmentKey {
    @MainActor static var defaultValue: AppDependencies {
        AppDependencies.preview()
    }
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

extension View {
    func environment(_ dependencies: AppDependencies) -> some View {
        environment(\.appDependencies, dependencies)
    }
}
