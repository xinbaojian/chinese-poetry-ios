//
//  HomeView.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    private var totalPoemCount: Int {
        (try? PoemLoader.loadPoems().count) ?? 0
    }

    private var learnedCount: Int { records.count }
    private var dueReviewCount: Int {
        let engine = ReviewEngine()
        return records.filter { engine.isDueForReview(nextReviewDate: $0.nextReviewDate) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("今日任务")
                            .font(.title2.bold())
                        HStack(spacing: 16) {
                            StatCard(title: "待复习", value: "\(dueReviewCount)", color: .orange)
                            StatCard(title: "学习中", value: "\(learnedCount)", color: .green)
                            StatCard(title: "总共", value: "\(totalPoemCount)", color: .blue)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 4)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())],
                        spacing: 16
                    ) {
                        ActionButton(
                            title: "开始学习",
                            icon: "pencil.and.outline",
                            color: .green,
                            destination: AnyView(LearnView())
                        )

                        ActionButton(
                            title: "去复习",
                            icon: "arrow.clockwise",
                            color: .orange,
                            badgeCount: dueReviewCount > 0 ? dueReviewCount : nil,
                            destination: AnyView(ReviewView())
                        )

                        ActionButton(
                            title: "诗词库",
                            icon: "book.fill",
                            color: .blue,
                            destination: AnyView(PoemLibraryView())
                        )

                        ActionButton(
                            title: "去测验",
                            icon: "questionmark.circle",
                            color: .purple,
                            destination: learnedCount > 0
                                ? AnyView(QuizView())
                                : AnyView(EmptyActionView(message: "暂无已学诗词，请先学习", icon: "book"))
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("古诗词背诵")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let badgeCount: Int?
    let destination: AnyView

    init(title: String, icon: String, color: Color, badgeCount: Int? = nil, destination: AnyView) {
        self.title = title
        self.icon = icon
        self.color = color
        self.badgeCount = badgeCount
        self.destination = destination
    }

    private var badgeText: String? {
        guard let count = badgeCount, count > 0 else { return nil }
        return count > 99 ? "99+" : "\(count)"
    }

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .topTrailing) {
                if let text = badgeText {
                    Text(text)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(color, in: Capsule())
                        .padding(8)
                }
            }
        }
    }
}

struct EmptyActionView: View {
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("提示")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
