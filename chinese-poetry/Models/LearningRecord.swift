//
//  LearningRecord.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import Foundation
import SwiftData

struct ReviewEntry: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let level: MasteryLevel
}

@Model
final class LearningRecord {
    var poemId: String
    var learnedDate: Date
    var nextReviewDate: Date
    var masteryLevel: MasteryLevel
    var reviewCount: Int
    var reviewHistory: [ReviewEntry]

    init(
        poemId: String,
        learnedDate: Date = Date(),
        nextReviewDate: Date,
        masteryLevel: MasteryLevel = .fair,
        reviewCount: Int = 0,
        reviewHistory: [ReviewEntry] = []
    ) {
        self.poemId = poemId
        self.learnedDate = learnedDate
        self.nextReviewDate = nextReviewDate
        self.masteryLevel = masteryLevel
        self.reviewCount = reviewCount
        self.reviewHistory = reviewHistory
    }
}
