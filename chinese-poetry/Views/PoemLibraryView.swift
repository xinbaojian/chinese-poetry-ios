//
//  PoemLibraryView.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import SwiftUI
import SwiftData

struct PoemLibraryView: View {
    @State private var poems: [Poem] = []
    @State private var selectedGrade: Int? = nil
    @State private var searchText = ""

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
                    HStack(spacing: 8) {
                        GradePill(title: "全部", isSelected: selectedGrade == nil) {
                            selectedGrade = nil
                        }
                        ForEach(1...6, id: \.self) { grade in
                            GradePill(title: "\(grade)年级", isSelected: selectedGrade == grade) {
                                selectedGrade = grade
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

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
            .searchable(text: $searchText, prompt: "搜索诗词标题、作者、诗句")
            .navigationTitle("诗词库")
            .onAppear {
                poems = (try? PoemLoader.loadPoems()) ?? []
            }
        }
    }
}

struct GradePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    PoemLibraryView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
