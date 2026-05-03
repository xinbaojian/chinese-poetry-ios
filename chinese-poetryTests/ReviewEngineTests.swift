//
//  ReviewEngineTests.swift
//  chinese-poetryTests
//
//  Created by 辛保健 on 2026/5/3.
//

import Testing
import Foundation
@testable import chinese_poetry

struct ReviewEngineTests {
    @Test("熟练等级的复习间隔递增")
    func proficientIntervals() {
        let intervals = ReviewEngine.intervals(for: .proficient)
        #expect(intervals == [1, 2, 4, 7, 15])
    }

    @Test("一般等级的复习间隔缩短")
    func fairIntervals() {
        let intervals = ReviewEngine.intervals(for: .fair)
        #expect(intervals == [1, 1, 2, 4, 7])
    }

    @Test("不熟练等级的复习间隔最短")
    func weakIntervals() {
        let intervals = ReviewEngine.intervals(for: .weak)
        #expect(intervals == [1, 1, 1, 2, 4])
    }

    @Test("首次复习 nextReviewDate 为明天")
    func firstReviewDate() {
        let engine = ReviewEngine()
        let now = Date()
        let nextDate = engine.calculateNextReviewDate(reviewCount: 0, level: .proficient, from: now)
        let diff = Calendar.current.dateComponents([.day], from: now, to: nextDate).day
        #expect(diff == 1)
    }

    @Test("第3次熟练复习间隔为4天")
    func thirdReviewInterval() {
        let engine = ReviewEngine()
        let now = Date()
        let nextDate = engine.calculateNextReviewDate(reviewCount: 2, level: .proficient, from: now)
        let diff = Calendar.current.dateComponents([.day], from: now, to: nextDate).day
        #expect(diff == 4)
    }

    @Test("复习次数超过间隔数组后使用最后一个值")
    func overflowInterval() {
        let engine = ReviewEngine()
        let now = Date()
        let nextDate = engine.calculateNextReviewDate(reviewCount: 10, level: .proficient, from: now)
        let diff = Calendar.current.dateComponents([.day], from: now, to: nextDate).day
        #expect(diff == 15)
    }

    @Test("判断是否到期复习")
    func isDueForReview() {
        let engine = ReviewEngine()
        let yesterday = Date().addingTimeInterval(-86400)
        let tomorrow = Date().addingTimeInterval(86400)
        #expect(engine.isDueForReview(nextReviewDate: yesterday))
        #expect(!engine.isDueForReview(nextReviewDate: tomorrow))
    }
}
