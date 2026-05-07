import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var poems: [Poem] = []
    @State private var currentIndex = 0
    @State private var isHidden = false
    @State private var reviewingRecord: LearningRecord?
    @State private var selectedTab = 0
    @State private var reviewedInSession = 0
    @State private var showingRecitation = false

    private let engine = ReviewEngine()

    private var dueRecords: [LearningRecord] {
        records.filter { engine.isDueForReview(nextReviewDate: $0.nextReviewDate) }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    private var poemMap: [String: Poem] {
        Dictionary(uniqueKeysWithValues: poems.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("待复习").tag(0)
                    Text("已学习").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    reviewTab
                } else {
                    learnedTab
                }
            }
            .navigationTitle("复习")
            .onAppear {
                poems = (try? PoemLoader.loadPoems()) ?? []
            }
            .onChange(of: dueRecords.count) {
                if currentIndex >= dueRecords.count {
                    currentIndex = max(0, dueRecords.count - 1)
                }
            }
    }

    // MARK: - 待复习 Tab

    private var reviewTab: some View {
        Group {
            if dueRecords.isEmpty && reviewedInSession > 0 {
                emptyState(message: "今日复习全部完成！", subtitle: "完成了\(reviewedInSession)首", icon: "checkmark.circle")
            } else if dueRecords.isEmpty {
                emptyState(message: "今天没有待复习的诗词", subtitle: "继续加油！", icon: "party.popper")
            } else {
                reviewContent
            }
        }
    }

    private var reviewContent: some View {
        VStack(spacing: 16) {
            Text("第 \(currentIndex + 1) / \(dueRecords.count) 首")
                .foregroundStyle(.secondary)

            TabView(selection: $currentIndex) {
                ForEach(Array(dueRecords.enumerated()), id: \.element.poemId) { index, record in
                    poemReviewPage(record: record)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 16) {
                Button(isHidden ? "显示原文" : "遮挡自测") {
                    isHidden.toggle()
                }
                .font(.headline)
                .padding()
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button(action: { showingRecitation = true }) {
                    Label("语音背诵", systemImage: "mic.fill")
                }
                .font(.headline)
                .padding()
                .background(Color.purple.opacity(0.15))
                .foregroundStyle(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("完成复习") {
                    if currentIndex < dueRecords.count {
                        reviewingRecord = dueRecords[currentIndex]
                    }
                }
                .font(.headline)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .sheet(isPresented: $showingRecitation) {
            if currentIndex < dueRecords.count,
               let poem = poemMap[dueRecords[currentIndex].poemId] {
                RecitationView(poem: poem, onComplete: { showingRecitation = false })
            }
        }
        .sheet(item: $reviewingRecord) { record in
            if let poem = poemMap[record.poemId] {
                MasteryPicker(poem: poem) { level in
                    updateRecord(record, level: level)
                    reviewingRecord = nil
                    isHidden = false
                    reviewedInSession += 1
                }
            }
        }
    }

    @ViewBuilder
    private func poemReviewPage(record: LearningRecord) -> some View {
        if let poem = poemMap[record.poemId] {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(poem.title)
                            .font(.title.bold())
                        Text("\(poem.dynasty) · \(poem.author)")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 16) {
                        ForEach(Array(poem.displayLines.enumerated()), id: \.offset) { _, line in
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
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 已学习 Tab

    private var learnedTab: some View {
        Group {
            if records.isEmpty {
                emptyState(message: "还没有加入学习计划的诗词", subtitle: "去诗词库挑选吧！", icon: "book")
            } else {
                List {
                    ForEach(records) { record in
                        if let poem = poemMap[record.poemId] {
                            NavigationLink(destination: PoemDetailView(poem: poem)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(poem.title)
                                        .font(.headline)
                                    Text("\(poem.dynasty) · \(poem.author)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        Label(masteryText(record.masteryLevel), systemImage: masteryIcon(record.masteryLevel))
                                            .font(.caption)
                                            .foregroundStyle(masteryColor(record.masteryLevel))
                                        Text("复习\(record.reviewCount)次")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("下次 \(nextReviewText(record.nextReviewDate))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(record)
                                } label: {
                                    Label("移出", systemImage: "minus.circle")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func emptyState(message: String, subtitle: String?, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text(message)
                .font(.title3)
            if let subtitle {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func masteryText(_ level: MasteryLevel) -> String {
        switch level {
        case .proficient: "熟练"
        case .fair: "一般"
        case .weak: "不熟练"
        }
    }

    private func masteryIcon(_ level: MasteryLevel) -> String {
        switch level {
        case .proficient: "star.fill"
        case .fair: "star.leadinghalf.filled"
        case .weak: "star"
        }
    }

    private func masteryColor(_ level: MasteryLevel) -> Color {
        switch level {
        case .proficient: .green
        case .fair: .orange
        case .weak: .red
        }
    }

    private func nextReviewText(_ date: Date) -> String {
        if date <= Date() {
            return "需复习"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
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
