//
//  audio_earningApp.swift
//  audio-earning
//
//  Created by Chen Liangyu on 2025/10/27.
//

import SwiftUI

@main
struct audio_earningApp: App {
    @StateObject private var dependencies = AppDependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.dependencies, dependencies)
        }
    }
}
