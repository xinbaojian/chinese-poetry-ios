//
//  PoemLoader.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import Foundation

struct PoemLoader {
    static func loadPoems() throws -> [Poem] {
        guard let url = Bundle.main.url(forResource: "poems", withExtension: "json") else {
            throw PoemError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Poem].self, from: data)
    }

    static func filter(poems: [Poem], byGrade grade: Int) -> [Poem] {
        poems.filter { $0.grade == grade }
    }

    static func search(poems: [Poem], query: String) -> [Poem] {
        guard !query.isEmpty else { return poems }
        return poems.filter {
            $0.title.contains(query) ||
            $0.author.contains(query) ||
            $0.paragraphs.contains { $0.contains(query) }
        }
    }
}

enum PoemError: Error {
    case fileNotFound
}
