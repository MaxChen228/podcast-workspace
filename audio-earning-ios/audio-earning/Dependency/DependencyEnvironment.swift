//
//  DependencyEnvironment.swift
//  audio-earning
//
//  Created by Codex on 2025/11/05.
//

import SwiftUI

private struct DependencyContainerKey: EnvironmentKey {
    @MainActor
    static var defaultValue: DependencyResolving = AppDependencyContainer()
}

extension EnvironmentValues {
    @MainActor
    var dependencies: DependencyResolving {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
