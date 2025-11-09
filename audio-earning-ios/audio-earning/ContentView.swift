//
//  ContentView.swift
//  audio-earning
//
//  Created by Chen Liangyu on 2025/10/27.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.dependencies) private var dependencies
    @StateObject private var tabRouter = TabRouter()

    var body: some View {
        TabView(selection: $tabRouter.selection) {
            NavigationStack {
                NewsFeedView(viewModel: dependencies.makeNewsFeedViewModel())
            }
            .tabItem {
                Label("新聞", systemImage: "newspaper")
            }
            .tag(AppTab.news)

            NavigationStack {
                BookListView(viewModel: dependencies.makeBookListViewModel())
            }
            .tabItem {
                Label("書庫", systemImage: "books.vertical")
            }
            .tag(AppTab.library)

            NavigationStack {
                BookCatalogView(viewModel: dependencies.makeBookCatalogViewModel())
            }
            .tabItem {
                Label("書城", systemImage: "cart")
            }
            .tag(AppTab.catalog)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .environmentObject(tabRouter)
    }
}

#Preview {
    ContentView()
}
