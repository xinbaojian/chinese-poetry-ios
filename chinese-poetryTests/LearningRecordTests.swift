//
//  LearningRecordTests.swift
//  chinese-poetryTests
//
//  Created by 辛保健 on 2026/5/3.
//

import Testing
import Foundation
import SwiftData
@testable import chinese_poetry

struct LearningRecordTests {

    @Test("创建 LearningRecord 默认值正确")
    func createRecord() {
        let record = LearningRecord(
            poemId: "p001",
            nextReviewDate: Date().addingTimeInterval(86400)
        )
        #expect(record.poemId == "p001")
        #expect(record.reviewCount == 0)
        #expect(record.reviewHistory.isEmpty)
        #expect(record.masteryLevel == .fair)
    }

    @Test("LearningRecord 可插入 ModelContext")
    func insertIntoContainer() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LearningRecord.self,
            configurations: config
        )
        let context = ModelContext(container)
        let record = LearningRecord(
            poemId: "p001",
            nextReviewDate: Date()
        )
        context.insert(record)

        // 验证插入后可从 context 中 fetch
        let descriptor = FetchDescriptor<LearningRecord>()
        let records = try context.fetch(descriptor)
        #expect(records.count == 1)
        #expect(records[0].poemId == "p001")
    }
}
