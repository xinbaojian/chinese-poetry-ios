//
//  LearnView.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import SwiftUI
import SwiftData

struct LearnView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var poems: [Poem] = []
    @State private var currentPoemIndex = 0
    @State private var isHidden = false
    @State private var translationExpanded = true
    @State private var showingRecitation = false
    @State private var showMasterySheet = false

    @AppStorage("dailyNewLimit") private var dailyNewLimit = 5
    @AppStorage("learnMode") private var learnMode = "sequential"
    @AppStorage("showPinyin") private var showPinyin = true
    @AppStorage("todayNewCount") private var todayNewCount = 0
    @AppStorage("lastNewDate") private var lastNewDate = ""

    private var unlearnedPoems: [Poem] {
        let learnedIds = Set(records.map(\.poemId))
        var result = poems.filter { !learnedIds.contains($0.id) }
        if learnMode == "random" {
            result.shuffle()
        }
        return result
    }

    private var canLearnMore: Bool {
        todayDateString == lastNewDate ? todayNewCount < dailyNewLimit : true
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var body: some View {
        Group {
                if unlearnedPoems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("所有诗词都已加入学习计划")
                            .font(.title3)
                    }
                } else if !canLearnMore {
                    VStack(spacing: 12) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                        Text("今日新学已达上限 (\(dailyNewLimit)首)")
                            .font(.title3)
                        Text("明天继续加油！")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    learnContent
                }
            }
            .navigationTitle("学习")
            .onAppear {
                poems = (try? PoemLoader.loadPoems()) ?? []
                currentPoemIndex = 0
            }
    }

    private var learnContent: some View {
        let poem = unlearnedPoems[min(currentPoemIndex, unlearnedPoems.count - 1)]
        return ScrollView {
            VStack(spacing: 24) {
                Text("第 \(currentPoemIndex + 1) / \(unlearnedPoems.count) 首")
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text(poem.title)
                        .font(.title.bold())
                    Text("\(poem.dynasty) · \(poem.author)")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    ForEach(Array(poem.displayLines.enumerated()), id: \.offset) { _, line in
                        if isHidden {
                            Text(String(repeating: "＿", count: line.count))
                                .font(.title2)
                        } else {
                            PinyinText(line, showPinyin: showPinyin, fontSize: 26)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                if let translation = poem.translation {
                    DisclosureGroup("查看释义", isExpanded: $translationExpanded) {
                        Text(translation)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button(action: { isHidden.toggle() }) {
                            Label(isHidden ? "显示原文" : "遮挡自测",
                                  systemImage: isHidden ? "eye.fill" : "eye.slash.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.secondaryAction)

                        Button(action: { showingRecitation = true }) {
                            Label("语音背诵", systemImage: "mic.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.secondaryAction)
                    }

                    Button {
                        showMasterySheet = true
                    } label: {
                        Label("完成背诵", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryAction)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingRecitation) {
            RecitationView(poem: poem)
        }
        .sheet(isPresented: $showMasterySheet) {
            MasteryPicker(poem: poem, onSelect: { level in
                addRecord(poem: poem, level: level)
                showMasterySheet = false
                if lastNewDate != todayDateString {
                    lastNewDate = todayDateString
                    todayNewCount = 1
                } else {
                    todayNewCount += 1
                }
                currentPoemIndex += 1
                isHidden = false
            })
        }
    }

    private func addRecord(poem: Poem, level: MasteryLevel) {
        let engine = ReviewEngine()
        let nextDate = engine.calculateNextReviewDate(
            reviewCount: 0, level: level, from: Date()
        )
        let record = LearningRecord(
            poemId: poem.id, nextReviewDate: nextDate, masteryLevel: level
        )
        modelContext.insert(record)
    }
}

struct MasteryPicker: View {
    let poem: Poem
    let onSelect: (MasteryLevel) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(poem.title)
                    .font(.title2.bold())
                Text("这首诗背得怎么样？")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button { onSelect(.proficient) } label: {
                    Label("熟练 — 很流利！", systemImage: "star.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button { onSelect(.fair) } label: {
                    Label("一般 — 有些卡壳", systemImage: "star.leadinghalf.filled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button { onSelect(.weak) } label: {
                    Label("不熟练 — 需要多练", systemImage: "star")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationTitle("掌握程度")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
#if os(iOS)
        .presentationDetents([.medium])
#endif
    }
}

#Preview {
    LearnView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
