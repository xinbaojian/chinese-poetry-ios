import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let recordCount: Int
    let settings: BackupSettings
    let records: [BackupRecord]
}

struct BackupSettings: Codable {
    let dailyNewLimit: Int
    let learnMode: String
    let showPinyin: Bool
    let autoHideContent: Bool
    let reminderEnabled: Bool
    let reminderHour: Int
    let reminderMinute: Int
}

struct BackupRecord: Codable {
    let poemId: String
    let learnedDate: Date
    let nextReviewDate: Date
    let masteryLevel: MasteryLevel
    let reviewCount: Int
    let reviewHistory: [ReviewEntry]
}

final class BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
