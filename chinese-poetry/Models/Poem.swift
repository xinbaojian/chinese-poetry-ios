//
//  Poem.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import Foundation

struct Poem: Identifiable, Hashable {
    let id: UInt64
    let title: String
    let poetName: String
    let dynasty: String
    let category: String
    let grade: UInt8
    let content: String
    let translation: String?

    var paragraphs: [String] {
        guard let data = content.data(using: .utf8),
              let lines = try? JSONDecoder().decode([String].self, from: data) else {
            return [content]
        }
        return lines
    }

    var displayLines: [String] {
        paragraphs.flatMap { line in
            var result: [String] = []
            var current = ""
            for char in line {
                current.append(char)
                if "，。！？；".contains(char) {
                    result.append(current)
                    current = ""
                }
            }
            if !current.isEmpty {
                result.append(current)
            }
            return result.isEmpty && current.isEmpty ? [line] : result
        }
    }

    init(id: UInt64, title: String, poetName: String, dynasty: String, category: String, grade: UInt8, content: String, translation: String? = nil) {
        self.id = id
        self.title = title
        self.poetName = poetName
        self.dynasty = dynasty
        self.category = category
        self.grade = grade
        self.content = content
        self.translation = translation
    }
}

// 兼容本地 JSON（author + paragraphs）和 API（poet_name + content）两种格式
extension Poem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, dynasty, category, grade, content, translation
        case author, paragraphs
        case poetName = "poet_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id: 支持字符串数字和整数
        if let str = try? c.decode(String.self, forKey: .id), let val = UInt64(str) {
            id = val
        } else {
            id = try c.decode(UInt64.self, forKey: .id)
        }
        title = try c.decode(String.self, forKey: .title)
        dynasty = try c.decode(String.self, forKey: .dynasty)
        category = try c.decode(String.self, forKey: .category)
        grade = try c.decode(UInt8.self, forKey: .grade)
        translation = try c.decodeIfPresent(String.self, forKey: .translation)

        // poetName: API 用 poet_name，本地 JSON 用 author
        if let name = try? c.decode(String.self, forKey: .poetName) {
            poetName = name
        } else {
            poetName = try c.decode(String.self, forKey: .author)
        }

        // content: API 用 JSON 字符串，本地 JSON 用 paragraphs 数组
        if let str = try? c.decode(String.self, forKey: .content) {
            content = str
        } else if let lines = try? c.decode([String].self, forKey: .paragraphs),
                  let data = try? JSONEncoder().encode(lines),
                  let str = String(data: data, encoding: .utf8) {
            content = str
        } else {
            content = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(poetName, forKey: .poetName)
        try c.encode(dynasty, forKey: .dynasty)
        try c.encode(category, forKey: .category)
        try c.encode(grade, forKey: .grade)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(translation, forKey: .translation)
    }
}
