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
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "导出数据编码失败"
        case .decodingFailed: "备份文件解析失败"
        case .invalidFormat: "备份文件格式不正确"
        case .validationFailed(let reason): "备份数据校验失败：\(reason)"
        }
    }
}

struct BackupService {
    private static let currentVersion = 2

    static func exportData(records: [LearningRecord], settings: BackupSettings) throws -> Data {
        let backupRecords = records.map { record in
            BackupRecord(
                poemId: record.poemId,
                poemTitle: record.poemTitle,
                poetName: record.poetName,
                learnedDate: record.learnedDate,
                nextReviewDate: record.nextReviewDate,
                masteryLevel: record.masteryLevel,
                reviewCount: record.reviewCount,
                updatedAt: record.updatedAt,
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
        var mutableData = data
        if let str = String(data: data, encoding: .utf8) {
            if str.contains("\"proficient\"") || str.contains("\"fair\"") || str.contains("\"weak\"") {
                let migrated = str
                    .replacingOccurrences(of: "\"proficient\"", with: "\"mastered\"")
                    .replacingOccurrences(of: "\"fair\"", with: "\"learning\"")
                    .replacingOccurrences(of: "\"weak\"", with: "\"learning\"")
                mutableData = Data(migrated.utf8)
            }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(BackupData.self, from: mutableData) else {
            throw BackupError.decodingFailed
        }

        guard backup.version <= currentVersion else {
            throw BackupError.invalidFormat
        }

        guard backup.recordCount == backup.records.count else {
            throw BackupError.validationFailed("记录数不一致")
        }

        for record in backup.records {
            guard record.poemId > 0 else {
                throw BackupError.validationFailed("无效的诗词ID")
            }
            guard record.reviewCount >= 0 else {
                throw BackupError.validationFailed("无效的复习次数")
            }
            let now = Date()
            guard record.learnedDate < now.addingTimeInterval(86400) else {
                throw BackupError.validationFailed("无效的学习日期")
            }
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
                    if record.updatedAt > existingRecord.updatedAt {
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
        autoHideContent: Bool,
        reminderEnabled: Bool,
        reminderHour: Int,
        reminderMinute: Int
    ) -> BackupSettings {
        BackupSettings(
            dailyNewLimit: dailyNewLimit,
            learnMode: learnMode,
            showPinyin: showPinyin,
            autoHideContent: autoHideContent,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }

    static func applySettings(_ settings: BackupSettings) {
        UserDefaults.standard.set(clamp(settings.dailyNewLimit, in: 1...999), forKey: "dailyNewLimit")
        UserDefaults.standard.set(["sequential", "random"].contains(settings.learnMode) ? settings.learnMode : "sequential", forKey: "learnMode")
        UserDefaults.standard.set(settings.showPinyin, forKey: "showPinyin")
        UserDefaults.standard.set(settings.autoHideContent, forKey: "autoHideContent")
        UserDefaults.standard.set(settings.reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(clamp(settings.reminderHour, in: 0...23), forKey: "reminderHour")
        UserDefaults.standard.set(clamp(settings.reminderMinute, in: 0...59), forKey: "reminderMinute")
    }

    private static func clamp(_ value: Int, in range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
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
            poemTitle: record.poemTitle,
            poetName: record.poetName,
            learnedDate: record.learnedDate,
            nextReviewDate: record.nextReviewDate,
            masteryLevel: record.masteryLevel,
            reviewCount: record.reviewCount,
            updatedAt: record.updatedAt,
            reviewHistory: record.reviewHistory
        )
        context.insert(learningRecord)
    }
}
