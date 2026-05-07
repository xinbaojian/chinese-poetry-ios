import Foundation
import SwiftData

enum ImportMode {
    case replace
    case merge
}

enum BackupError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "导出数据编码失败"
        case .decodingFailed: "备份文件解析失败"
        case .invalidFormat: "备份文件格式不正确"
        }
    }
}

struct BackupService {
    private static let currentVersion = 1

    static func exportData(records: [LearningRecord], settings: BackupSettings) throws -> Data {
        let backupRecords = records.map { record in
            BackupRecord(
                poemId: record.poemId,
                learnedDate: record.learnedDate,
                nextReviewDate: record.nextReviewDate,
                masteryLevel: record.masteryLevel,
                reviewCount: record.reviewCount,
                reviewHistory: record.reviewHistory
            )
        }

        let backup = BackupData(
            version: currentVersion,
            exportDate: Date(),
            recordCount: backupRecords.count,
            settings: settings,
            records: backupRecords
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(backup) else {
            throw BackupError.encodingFailed
        }
        return data
    }

    static func parseBackup(from data: Data) throws -> BackupData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(BackupData.self, from: data) else {
            throw BackupError.decodingFailed
        }

        guard backup.version <= currentVersion else {
            throw BackupError.invalidFormat
        }

        return backup
    }

    static func importData(_ backup: BackupData, mode: ImportMode, context: ModelContext) throws {
        switch mode {
        case .replace:
            try context.delete(model: LearningRecord.self)
            insertRecords(backup.records, into: context)
        case .merge:
            let existing = try context.fetch(FetchDescriptor<LearningRecord>())
            let existingMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.poemId, $0) })

            for record in backup.records {
                if let existingRecord = existingMap[record.poemId] {
                    if record.learnedDate > existingRecord.learnedDate {
                        context.delete(existingRecord)
                        insertRecord(record, into: context)
                    }
                } else {
                    insertRecord(record, into: context)
                }
            }
        }

        try context.save()
    }

    static func buildSettings(
        dailyNewLimit: Int,
        learnMode: String,
        showPinyin: Bool,
        reminderEnabled: Bool,
        reminderHour: Int,
        reminderMinute: Int
    ) -> BackupSettings {
        BackupSettings(
            dailyNewLimit: dailyNewLimit,
            learnMode: learnMode,
            showPinyin: showPinyin,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }

    static func applySettings(_ settings: BackupSettings) {
        UserDefaults.standard.set(settings.dailyNewLimit, forKey: "dailyNewLimit")
        UserDefaults.standard.set(settings.learnMode, forKey: "learnMode")
        UserDefaults.standard.set(settings.showPinyin, forKey: "showPinyin")
        UserDefaults.standard.set(settings.reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(settings.reminderHour, forKey: "reminderHour")
        UserDefaults.standard.set(settings.reminderMinute, forKey: "reminderMinute")
    }

    static func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let dateStr = formatter.string(from: Date())
        return "古诗词学习进度_\(dateStr).json"
    }

    private static func insertRecords(_ records: [BackupRecord], into context: ModelContext) {
        for record in records {
            insertRecord(record, into: context)
        }
    }

    private static func insertRecord(_ record: BackupRecord, into context: ModelContext) {
        let learningRecord = LearningRecord(
            poemId: record.poemId,
            learnedDate: record.learnedDate,
            nextReviewDate: record.nextReviewDate,
            masteryLevel: record.masteryLevel,
            reviewCount: record.reviewCount,
            reviewHistory: record.reviewHistory
        )
        context.insert(learningRecord)
    }
}
