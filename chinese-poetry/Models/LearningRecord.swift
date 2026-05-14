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
    var remoteId: UInt64?
    var poemId: UInt64
    var poemTitle: String
    var poetName: String
    var learnedDate: Date
    var nextReviewDate: Date
    var masteryLevel: MasteryLevel
    var reviewCount: Int
    var updatedAt: Date
    var reviewHistory: [ReviewEntry]

    init(
        remoteId: UInt64? = nil,
        poemId: UInt64,
        poemTitle: String = "",
        poetName: String = "",
        learnedDate: Date = Date(),
        nextReviewDate: Date,
        masteryLevel: MasteryLevel = .learning,
        reviewCount: Int = 0,
        updatedAt: Date = Date(),
        reviewHistory: [ReviewEntry] = []
    ) {
        self.remoteId = remoteId
        self.poemId = poemId
        self.poemTitle = poemTitle
        self.poetName = poetName
        self.learnedDate = learnedDate
        self.nextReviewDate = nextReviewDate
        self.masteryLevel = masteryLevel
        self.reviewCount = reviewCount
        self.updatedAt = updatedAt
        self.reviewHistory = reviewHistory
    }
}
