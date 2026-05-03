//
//  ReviewView.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var poems: [Poem] = []
    @State private var currentIndex = 0
    @State private var isHidden = false
    @State private var showMasterySheet = false

    private let engine = ReviewEngine()

    private var dueRecords: [LearningRecord] {
        records.filter { engine.isDueForReview(nextReviewDate: $0.nextReviewDate) }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    private var poemMap: [String: Poem] {
        Dictionary(uniqueKeysWithValues: poems.map { ($0.id, $0) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if dueRecords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "party.popper")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("今天没有待复习的诗词")
                            .font(.title3)
                        Text("继续加油！")
                            .foregroundStyle(.secondary)
                    }
                } else if currentIndex >= dueRecords.count {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("今日复习全部完成！")
                            .font(.title2.bold())
                    }
                } else {
                    reviewContent
                }
            }
            .navigationTitle("复习")
            .onAppear {
                poems = (try? PoemLoader.loadPoems()) ?? []
            }
        }
    }

    private var reviewContent: some View {
        let record = dueRecords[currentIndex]
        let poem = poemMap[record.poemId]
        return VStack(spacing: 24) {
            Text("第 \(currentIndex + 1) / \(dueRecords.count) 首")
                .foregroundStyle(.secondary)

            if let poem {
                VStack(spacing: 4) {
                    Text(poem.title)
                        .font(.title.bold())
                    Text("\(poem.dynasty) · \(poem.author)")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    ForEach(poem.paragraphs, id: \.self) { line in
                        Text(isHidden ? String(repeating: "＿", count: line.count) : line)
                            .font(.title2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                if let translation = poem.translation {
                    DisclosureGroup("查看释义") {
                        Text(translation)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }

            HStack(spacing: 16) {
                Button(isHidden ? "显示原文" : "遮挡自测") {
                    isHidden.toggle()
                }
                .font(.headline)
                .padding()
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("完成复习") {
                    showMasterySheet = true
                }
                .font(.headline)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showMasterySheet) {
            if let poem = poemMap[record.poemId] {
                MasteryPicker(poem: poem) { level in
                    updateRecord(record, level: level)
                    showMasterySheet = false
                    currentIndex += 1
                    isHidden = false
                }
            }
        }
    }

    private func updateRecord(_ record: LearningRecord, level: MasteryLevel) {
        record.masteryLevel = level
        record.reviewCount += 1
        record.reviewHistory.append(ReviewEntry(date: Date(), level: level))
        record.nextReviewDate = engine.calculateNextReviewDate(
            reviewCount: record.reviewCount, level: level, from: Date()
        )
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
