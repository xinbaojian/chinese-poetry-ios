import SwiftUI
import SwiftData

struct PoemLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var poems: [Poem] = []
    @State private var selectedGrade: Int? = nil
    @State private var selectedCategory: String? = nil
    @State private var showLearnedOnly = false
    @State private var searchText = ""
    @State private var isLoading = false

    private let categories = ["唐诗", "宋词"]

    private var learnedIds: Set<String> { Set(records.map(\.poemId)) }

    private var filteredPoems: [Poem] {
        var result = poems
        if showLearnedOnly {
            result = result.filter { learnedIds.contains($0.id) }
        }
        if let grade = selectedGrade {
            result = PoemLoader.filter(poems: result, byGrade: grade)
        }
        if !searchText.isEmpty {
            result = PoemLoader.search(poems: result, query: searchText)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            FilterPill(title: "部编版", isSelected: !showLearnedOnly && selectedCategory == nil && selectedGrade == nil) {
                                selectDefault()
                            }
                            FilterPill(title: "学习中", isSelected: showLearnedOnly) {
                                showLearnedOnly.toggle()
                                if showLearnedOnly {
                                    selectedCategory = nil
                                }
                            }
                            ForEach(categories, id: \.self) { category in
                                FilterPill(title: category, isSelected: selectedCategory == category) {
                                    selectCategory(category)
                                }
                            }
                        }
                        if !showLearnedOnly && selectedCategory == nil {
                            HStack(spacing: 8) {
                                ForEach(1...6, id: \.self) { grade in
                                    FilterPill(title: "\(grade)年级", isSelected: selectedGrade == grade) {
                                        selectedGrade = grade
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if isLoading {
                    Spacer()
                    ProgressView("加载中…")
                    Spacer()
                } else {
                    List {
                        ForEach(filteredPoems) { poem in
                            NavigationLink(destination: PoemDetailView(poem: poem)) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(poem.title)
                                            .font(.headline)
                                        Text("\(poem.dynasty) · \(poem.author)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text(poem.paragraphs.first ?? "")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if learnedIds.contains(poem.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.title3)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .swipeActions(edge: .leading) {
                                if learnedIds.contains(poem.id) {
                                    Button { removeFromLearning(poem) } label: {
                                        Label("移出学习", systemImage: "minus.circle")
                                    }
                                    .tint(.red)
                                } else {
                                    Button { addToLearning(poem) } label: {
                                        Label("加入学习", systemImage: "plus.circle")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索诗词标题、作者、诗句")
            .navigationTitle("诗词库")
            .toolbar {
                if !poems.isEmpty {
                    ToolbarItem(placement: .status) {
                        Text("\(filteredPoems.count) 首")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                if poems.isEmpty {
                    poems = (try? PoemLoader.loadPoems()) ?? []
                }
            }
        }
    }

    private func selectDefault() {
        selectedCategory = nil
        selectedGrade = nil
        showLearnedOnly = false
        poems = (try? PoemLoader.loadPoems()) ?? []
    }

    private func selectCategory(_ category: String) {
        selectedCategory = category
        selectedGrade = nil
        showLearnedOnly = false
        isLoading = true
        Task {
            poems = (try? await PoemLoader.loadCategoryPoems(category: category)) ?? []
            isLoading = false
        }
    }

    private func addToLearning(_ poem: Poem) {
        let engine = ReviewEngine()
        let nextDate = engine.calculateNextReviewDate(reviewCount: 0, level: .fair, from: Date())
        let record = LearningRecord(poemId: poem.id, nextReviewDate: nextDate)
        modelContext.insert(record)
    }

    private func removeFromLearning(_ poem: Poem) {
        for record in records where record.poemId == poem.id {
            modelContext.delete(record)
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    PoemLibraryView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
