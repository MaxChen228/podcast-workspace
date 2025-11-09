//
//  ContentView.swift
//  audio-earning
//
//  Created by Chen Liangyu on 2025/10/27.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        TabView {
            NavigationStack {
                NewsFeedView(viewModel: dependencies.makeNewsFeedViewModel())
            }
            .tabItem {
                Label("新聞", systemImage: "newspaper")
            }

            NavigationStack {
                BookListView(viewModel: dependencies.makeBookListViewModel())
            }
            .tabItem {
                Label("書籍", systemImage: "books.vertical")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
}
