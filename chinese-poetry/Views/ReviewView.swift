import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var poems: [Poem] = []
    @State private var currentIndex = 0
    @AppStorage("autoHideContent") private var autoHideContent = false
    @State private var isHidden = false
    @State private var translationExpanded = true
    @State private var reviewingRecord: LearningRecord?
    @State private var selectedTab = 0
    @State private var reviewedInSession = 0
    @State private var showingRecitation = false
    @State private var learnedSortOrder: LearnedSortOrder = .nextReview

    private let engine = ReviewEngine()

    enum LearnedSortOrder: String, CaseIterable {
        case nextReview = "下次复习"
        case learnedDate = "学习时间"
        case mastery = "掌握程度"
    }

    private var sortedLearnedRecords: [LearningRecord] {
        switch learnedSortOrder {
        case .nextReview:
            records.sorted { $0.nextReviewDate < $1.nextReviewDate }
        case .learnedDate:
            records.sorted { $0.learnedDate > $1.learnedDate }
        case .mastery:
            records.sorted {
                let o1 = masteryOrder($0.masteryLevel), o2 = masteryOrder($1.masteryLevel)
                return o1 == o2 ? $0.nextReviewDate < $1.nextReviewDate : o1 < o2
            }
        }
    }

    private func masteryOrder(_ level: MasteryLevel) -> Int {
        switch level {
        case .weak: 0
        case .fair: 1
        case .proficient: 2
        }
    }

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
                isHidden = autoHideContent
            }
            .onChange(of: dueRecords.count) {
                if currentIndex >= dueRecords.count {
                    currentIndex = max(0, dueRecords.count - 1)
                }
            }
            .onChange(of: currentIndex) {
                isHidden = autoHideContent
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
                    if currentIndex < dueRecords.count {
                        reviewingRecord = dueRecords[currentIndex]
                    }
                } label: {
                    Label("完成复习", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
            }
        }
        .padding()
        .sheet(isPresented: $showingRecitation) {
            if currentIndex < dueRecords.count,
               let poem = poemMap[dueRecords[currentIndex].poemId] {
                RecitationView(poem: poem)
            }
        }
        .sheet(item: $reviewingRecord) { record in
            if let poem = poemMap[record.poemId] {
                MasteryPicker(poem: poem) { level in
                    updateRecord(record, level: level)
                    reviewingRecord = nil
                    isHidden = autoHideContent
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
                        DisclosureGroup("查看释义", isExpanded: $translationExpanded) {
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
                    Section {
                        ForEach(sortedLearnedRecords) { record in
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
                    } header: {
                        HStack {
                            Text("\(records.count)首")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Menu {
                                ForEach(LearnedSortOrder.allCases, id: \.self) { order in
                                    Button {
                                        learnedSortOrder = order
                                    } label: {
                                        HStack {
                                            Text(order.rawValue)
                                            if learnedSortOrder == order {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.up.arrow.down")
                                    Text(learnedSortOrder.rawValue)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
// MARK: - Button Styles

struct PrimaryActionButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryActionButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)
            .foregroundStyle(.blue)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryActionButton {
    static var primaryAction: PrimaryActionButton { PrimaryActionButton() }
}

extension ButtonStyle where Self == SecondaryActionButton {
    static var secondaryAction: SecondaryActionButton { SecondaryActionButton() }
}

#Preview {
    ReviewView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
