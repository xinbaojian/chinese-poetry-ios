//
//  Poem.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import Foundation

struct Poem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let dynasty: String
    let category: String
    let grade: Int
    let paragraphs: [String]
    let translation: String?

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
}
