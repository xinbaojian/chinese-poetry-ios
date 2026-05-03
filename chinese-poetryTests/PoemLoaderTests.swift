//
//  PoemLoaderTests.swift
//  chinese-poetryTests
//
//  Created by 辛保健 on 2026/5/3.
//

import Testing
import Foundation
@testable import chinese_poetry

struct PoemLoaderTests {
    @Test("从 Bundle 加载诗词列表")
    func loadPoems() throws {
        let poems = try PoemLoader.loadPoems()
        #expect(!poems.isEmpty)
    }

    @Test("按年级筛选诗词")
    func filterByGrade() throws {
        let poems = try PoemLoader.loadPoems()
        let grade1 = PoemLoader.filter(poems: poems, byGrade: 1)
        let grade2 = PoemLoader.filter(poems: poems, byGrade: 2)
        #expect(grade1.allSatisfy { $0.grade == 1 })
        #expect(grade2.allSatisfy { $0.grade == 2 })
    }

    @Test("搜索诗词按标题和作者")
    func searchPoems() throws {
        let poems = try PoemLoader.loadPoems()
        let results = PoemLoader.search(poems: poems, query: "李白")
        #expect(results.allSatisfy { $0.author.contains("李白") })
    }
}
