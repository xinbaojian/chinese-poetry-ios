//
//  ReviewEngine.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import Foundation

struct ReviewEngine {
    static func intervals(for level: MasteryLevel) -> [Int] {
        switch level {
        case .mastered:  [2, 4, 7, 15, 30]
        case .reviewing: [1, 2, 4, 7, 15]
        case .learning:  [1, 1, 2, 4, 7]
        case .new:       [1, 1, 2, 4, 7]
        }
    }

    func calculateNextReviewDate(reviewCount: Int, level: MasteryLevel, from date: Date) -> Date {
        let intervals = Self.intervals(for: level)
        let index = min(reviewCount, intervals.count - 1)
        let days = intervals[index]
        return Calendar.current.date(byAdding: .day, value: days, to: date)!
    }

    func isDueForReview(nextReviewDate: Date) -> Bool {
        nextReviewDate <= Date()
    }
}
