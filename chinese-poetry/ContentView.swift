//
//  ContentView.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
            PoemLibraryView()
                .tabItem { Label("诗词库", systemImage: "book.fill") }
            LearnView()
                .tabItem { Label("学习", systemImage: "pencil.and.outline") }
            ReviewView()
                .tabItem { Label("复习", systemImage: "arrow.clockwise") }
            QuizView()
                .tabItem { Label("测验", systemImage: "questionmark.circle") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
