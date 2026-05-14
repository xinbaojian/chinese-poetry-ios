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

    @AppStorage("serverBaseURL") private var serverBaseURL = "https://poetry.xiuyuan.xin"
    @AppStorage("isLoggedIn") private var isLoggedIn = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !serverBaseURL.isEmpty && isLoggedIn {
                    ContentView()
                        .task { await initialSync() }
                } else if !serverBaseURL.isEmpty {
                    AuthView(onSuccess: { isLoggedIn = true })
                } else {
                    ContentView()
                }
            }
            .onAppear {
                if !serverBaseURL.isEmpty {
                    isLoggedIn = AuthService.isLoggedIn
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func initialSync() async {
        guard AuthService.isLoggedIn else { return }
        let context = sharedModelContainer.mainContext
        do {
            // 先上传本地离线记录
            let descriptor = FetchDescriptor<LearningRecord>()
            let localRecords = try context.fetch(descriptor)
            if !localRecords.isEmpty {
                _ = try await SyncService.syncRecords(localRecords)
            }
            // 再拉取云端全量记录合并
            let remoteRecords = try await SyncService.fetchAllProgress()
            try SyncService.mergeRemoteRecords(remoteRecords, into: context)
        } catch {
            // 同步失败不阻塞 UI
        }
    }
}
