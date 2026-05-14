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
            // schema 变更导致旧库不兼容，删除旧库重建
            let url = config.url
            let urls = [url, url.deletingPathExtension().appendingPathExtension("sqlite-wal"), url.deletingPathExtension().appendingPathExtension("sqlite-shm")]
            for file in urls {
                try? FileManager.default.removeItem(at: file)
            }
            return try! ModelContainer(for: schema, configurations: [config])
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
        SyncManager.shared.isSyncing = true
        do {
            let descriptor = FetchDescriptor<LearningRecord>()
            let localRecords = try context.fetch(descriptor)
            if !localRecords.isEmpty {
                _ = try await SyncService.syncRecords(localRecords)
            }
            let remoteRecords = try await SyncService.fetchAllProgress()
            try SyncService.mergeRemoteRecords(remoteRecords, into: context)
            SyncManager.shared.lastSyncDate = Date()
            UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
        } catch {
            SyncManager.shared.lastSyncError = error.localizedDescription
        }
        SyncManager.shared.isSyncing = false
    }
}
