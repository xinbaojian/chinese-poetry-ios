//
//  MasteryLevel.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import Foundation

enum MasteryLevel: String, Codable, CaseIterable {
    case new        // 未学
    case learning   // 学习中
    case reviewing  // 复习中
    case mastered   // 已掌握
}
