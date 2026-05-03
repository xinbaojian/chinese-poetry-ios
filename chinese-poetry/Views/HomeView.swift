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

                    NavigationLink(destination: LearnView()) {
                        Label("开始今日学习", systemImage: "pencil.and.outline")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if dueReviewCount > 0 {
                        NavigationLink(destination: ReviewView()) {
                            Label("去复习 (\(dueReviewCount)首)", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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
