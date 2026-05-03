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

    private var isLearned: Bool {
        records.contains { $0.poemId == poem.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(poem.title)
                        .font(.title.bold())
                    Text("\(poem.dynasty) · \(poem.author)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(poem.paragraphs, id: \.self) { line in
                        Text(line)
                            .font(.title2)
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
                    Label("已加入学习计划", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle(poem.title)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func addToLearning() {
        let engine = ReviewEngine()
        let nextDate = engine.calculateNextReviewDate(
            reviewCount: 0, level: .fair, from: Date()
        )
        let record = LearningRecord(poemId: poem.id, nextReviewDate: nextDate)
        modelContext.insert(record)
    }
}

#Preview {
    NavigationStack {
        PoemDetailView(poem: Poem(
            id: "p001", title: "静夜思", author: "李白",
            dynasty: "唐", category: "唐诗", grade: 1,
            paragraphs: ["床前明月光，疑是地上霜。", "举头望明月，低头思故乡。"],
            translation: "明亮的月光洒在床前..."
        ))
    }
    .modelContainer(for: LearningRecord.self, inMemory: true)
}
