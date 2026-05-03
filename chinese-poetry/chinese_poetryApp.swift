//
//  chinese_poetryApp.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import SwiftUI
import SwiftData

@main
struct chinese_poetryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([LearningRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
