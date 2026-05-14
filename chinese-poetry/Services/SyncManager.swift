import Foundation
import SwiftUI

@Observable
class SyncManager {
    static let shared = SyncManager()

    var isSyncing = false
    var lastSyncDate: Date?
    var lastSyncError: String?

    private init() {
        if let ts = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = ts
        }
    }

    func sync(records: [LearningRecord]) async {
        guard AuthService.isLoggedIn, !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        do {
            _ = try await SyncService.syncRecords(records)
            markSynced()
        } catch {
            lastSyncError = error.localizedDescription
        }
        isSyncing = false
    }

    func delete(poemId: UInt64) async {
        guard AuthService.isLoggedIn else { return }
        do {
            try await SyncService.deleteRecord(poemId: poemId)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func markSynced() {
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
    }
}
