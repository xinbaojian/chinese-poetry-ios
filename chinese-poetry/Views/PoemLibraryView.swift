import SwiftUI
import SwiftData

struct PoemLibraryView: View {
    @State private var poems: [Poem] = []
    @State private var selectedGrade: Int? = nil
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var isLoading = false

    private let categories = ["唐诗", "宋词"]

    private var filteredPoems: [Poem] {
        var result = poems
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
                            FilterPill(title: "部编版", isSelected: selectedCategory == nil && selectedGrade == nil) {
                                selectDefault()
                            }
                            ForEach(categories, id: \.self) { category in
                                FilterPill(title: category, isSelected: selectedCategory == category) {
                                    selectCategory(category)
                                }
                            }
                        }
                        if selectedCategory == nil {
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
                    List(filteredPoems) { poem in
                        NavigationLink(destination: PoemDetailView(poem: poem)) {
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
                            .padding(.vertical, 2)
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
        poems = (try? PoemLoader.loadPoems()) ?? []
    }

    private func selectCategory(_ category: String) {
        selectedCategory = category
        selectedGrade = nil
        isLoading = true
        Task {
            poems = (try? await PoemLoader.loadCategoryPoems(category: category)) ?? []
            isLoading = false
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
