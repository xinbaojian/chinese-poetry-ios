import Foundation
import SwiftData

// MARK: - API 模型

struct RemoteLearningRecord: Decodable {
    let id: UInt64
    let poemId: UInt64
    let poemTitle: String
    let poetName: String
    let masteryLevel: String
    let reviewCount: UInt32
    let nextReviewDate: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case poemId = "poem_id"
        case poemTitle = "poem_title"
        case poetName = "poet_name"
        case masteryLevel = "mastery_level"
        case reviewCount = "review_count"
        case nextReviewDate = "next_review_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SyncRequest: Encodable {
    let records: [SyncRecord]
}

struct SyncRecord: Encodable {
    let poemId: UInt64
    let masteryLevel: String
    let reviewCount: UInt32
    let nextReviewDate: String?
    let updatedAt: String
}

struct SyncResponse: Decodable {
    let synced: UInt32
    let skipped: UInt32
}

// MARK: - SyncService

struct SyncService {
    private static let beijingFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return f
    }()

    private static func formatDate(_ date: Date) -> String {
        beijingFormatter.string(from: date)
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        if let date = beijingFormatter.date(from: string) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        fallback.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        if let date = fallback.date(from: string) { return date }
        // 兼容无时区后缀的格式
        let noTz = ISO8601DateFormatter()
        noTz.formatOptions = [.withInternetDateTime]
        return noTz.date(from: string)
    }

    // MARK: - 下拉（从云端拉取）

    static func fetchAllProgress() async throws -> [RemoteLearningRecord] {
        try await APIClient.shared.request("/progress")
    }

    static func fetchDueReviews() async throws -> [RemoteLearningRecord] {
        try await APIClient.shared.request("/progress/due")
    }

    // MARK: - 上传（同步本地记录到云端）

    static func syncRecords(_ records: [LearningRecord]) async throws -> SyncResponse {
        let syncRecords = records.map { record in
            SyncRecord(
                poemId: record.poemId,
                masteryLevel: record.masteryLevel.rawValue,
                reviewCount: UInt32(record.reviewCount),
                nextReviewDate: record.nextReviewDate > Date.distantPast ? formatDate(record.nextReviewDate) : nil,
                updatedAt: formatDate(record.updatedAt)
            )
        }
        let body = SyncRequest(records: syncRecords)
        return try await APIClient.shared.request("/progress", method: "POST", body: body)
    }

    // MARK: - 删除

    static func deleteRecord(poemId: UInt64) async throws {
        let _: EmptyResponse = try await APIClient.shared.request("/progress/\(poemId)", method: "DELETE")
    }

    // MARK: - 合并（云端记录覆盖本地）

    static func mergeRemoteRecords(_ remoteRecords: [RemoteLearningRecord], into context: ModelContext) throws {
        let descriptor = FetchDescriptor<LearningRecord>()
        let localRecords = try context.fetch(descriptor)
        var localByPoemId: [UInt64: LearningRecord] = [:]
        for r in localRecords { localByPoemId[r.poemId] = r }

        for remote in remoteRecords {
            let remoteUpdatedAt = parseDate(remote.updatedAt) ?? Date.distantPast

            if let local = localByPoemId[remote.poemId] {
                if remoteUpdatedAt > local.updatedAt {
                    applyRemote(remote, to: local)
                }
            } else {
                let record = createFromRemote(remote)
                context.insert(record)
            }
        }

        try context.save()
    }

    private static func applyRemote(_ remote: RemoteLearningRecord, to local: LearningRecord) {
        local.remoteId = remote.id
        local.poemTitle = remote.poemTitle
        local.poetName = remote.poetName
        local.masteryLevel = MasteryLevel(rawValue: remote.masteryLevel) ?? .learning
        local.reviewCount = Int(remote.reviewCount)
        local.nextReviewDate = parseDate(remote.nextReviewDate) ?? Date()
        local.updatedAt = parseDate(remote.updatedAt) ?? Date()
    }

    private static func createFromRemote(_ remote: RemoteLearningRecord) -> LearningRecord {
        LearningRecord(
            remoteId: remote.id,
            poemId: remote.poemId,
            poemTitle: remote.poemTitle,
            poetName: remote.poetName,
            learnedDate: parseDate(remote.createdAt) ?? Date(),
            nextReviewDate: parseDate(remote.nextReviewDate) ?? Date(),
            masteryLevel: MasteryLevel(rawValue: remote.masteryLevel) ?? .learning,
            reviewCount: Int(remote.reviewCount),
            updatedAt: parseDate(remote.updatedAt) ?? Date()
        )
    }
}

private struct EmptyResponse: Decodable {}
