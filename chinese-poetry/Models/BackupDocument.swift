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
    let poemId: UInt64
    let poemTitle: String
    let poetName: String
    let learnedDate: Date
    let nextReviewDate: Date
    let masteryLevel: MasteryLevel
    let reviewCount: Int
    let updatedAt: Date
    let reviewHistory: [ReviewEntry]

    // v1 兼容：poemId 可能是 String，缺少 poemTitle/poetName/updatedAt
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // poemId: 支持字符串数字和整数
        if let str = try? c.decode(String.self, forKey: .poemId), let val = UInt64(str) {
            poemId = val
        } else {
            poemId = try c.decode(UInt64.self, forKey: .poemId)
        }

        poemTitle = (try? c.decode(String.self, forKey: .poemTitle)) ?? ""
        poetName = (try? c.decode(String.self, forKey: .poetName)) ?? ""
        learnedDate = try c.decode(Date.self, forKey: .learnedDate)
        nextReviewDate = try c.decode(Date.self, forKey: .nextReviewDate)
        masteryLevel = try c.decode(MasteryLevel.self, forKey: .masteryLevel)
        reviewCount = try c.decode(Int.self, forKey: .reviewCount)
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? learnedDate
        reviewHistory = (try? c.decode([ReviewEntry].self, forKey: .reviewHistory)) ?? []
    }

    init(poemId: UInt64, poemTitle: String, poetName: String, learnedDate: Date, nextReviewDate: Date, masteryLevel: MasteryLevel, reviewCount: Int, updatedAt: Date, reviewHistory: [ReviewEntry]) {
        self.poemId = poemId
        self.poemTitle = poemTitle
        self.poetName = poetName
        self.learnedDate = learnedDate
        self.nextReviewDate = nextReviewDate
        self.masteryLevel = masteryLevel
        self.reviewCount = reviewCount
        self.updatedAt = updatedAt
        self.reviewHistory = reviewHistory
    }
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
