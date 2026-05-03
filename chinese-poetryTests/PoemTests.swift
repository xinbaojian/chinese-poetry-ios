//
//  PoemTests.swift
//  chinese-poetryTests
//
//  Created by 辛保健 on 2026/5/3.
//

import Testing
import Foundation
@testable import chinese_poetry

struct PoemTests {

    @Test("解码 poems.json")
    func decodePoems() throws {
        let url = Bundle.main.url(forResource: "poems", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let poems = try JSONDecoder().decode([Poem].self, from: data)
        #expect(poems.count == 5)
        #expect(poems[0].title == "静夜思")
        #expect(poems[0].grade == 1)
        #expect(poems[0].translation != nil)
    }

    @Test("Poem 结构体属性正确")
    func poemProperties() {
        let poem = Poem(
            id: "test", title: "测试", author: "作者",
            dynasty: "唐", grade: 3,
            paragraphs: ["第一句", "第二句"],
            translation: "释义"
        )
        #expect(poem.id == "test")
        #expect(poem.paragraphs.count == 2)
        #expect(poem.translation == "释义")
    }
}
