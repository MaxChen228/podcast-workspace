//
//  TabRouter.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import SwiftUI

enum AppTab: Hashable {
    case news
    case library
    case catalog
    case settings
}

final class TabRouter: ObservableObject {
    @Published var selection: AppTab = .news
}
