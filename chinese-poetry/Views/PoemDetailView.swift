//
//  PoemDetailView.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import SwiftUI
import SwiftData

struct PoemDetailView: View {
    let poem: Poem
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var showTranslation = false
    @AppStorage("showPinyin") private var showPinyin = true

    private var isLearned: Bool {
        records.contains { $0.poemId == poem.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 4) {
                    Text(poem.title)
                        .font(.title.bold())
                    Text("\(poem.dynasty) · \(poem.author)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(poem.displayLines.enumerated()), id: \.offset) { _, line in
                        PinyinText(line, showPinyin: showPinyin, fontSize: 26)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)

                if let translation = poem.translation {
                    DisclosureGroup("查看释义", isExpanded: $showTranslation) {
                        Text(translation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                    .font(.headline)
                }

                if !isLearned {
                    Button {
                        addToLearning()
                    } label: {
                        Label("加入学习计划", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button(role: .destructive) {
                        removeFromLearning()
                    } label: {
                        Label("移出学习计划", systemImage: "minus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("诗词详情")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPinyin.toggle()
                } label: {
                    Image(systemName: showPinyin ? "textformat.size.smaller" : "textformat.size.larger")
                }
            }
        }
    }

    private func addToLearning() {
        let engine = ReviewEngine()
        let nextDate = engine.calculateNextReviewDate(
            reviewCount: 0, level: .fair, from: Date()
        )
        let record = LearningRecord(poemId: poem.id, nextReviewDate: nextDate)
        modelContext.insert(record)
    }

    private func removeFromLearning() {
        for record in records where record.poemId == poem.id {
            modelContext.delete(record)
        }
    }
}

#Preview {
    NavigationStack {
        PoemDetailView(poem: Poem(
            id: "1", title: "静夜思", author: "李白",
            dynasty: "唐", category: "唐诗", grade: 1,
            paragraphs: ["床前明月光，疑是地上霜。", "举头望明月，低头思故乡。"],
            translation: "明亮的月光洒在床前..."
        ))
    }
    .modelContainer(for: LearningRecord.self, inMemory: true)
}
