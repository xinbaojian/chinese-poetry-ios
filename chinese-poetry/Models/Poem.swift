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
    let grade: Int
    let paragraphs: [String]
    let translation: String?
}
