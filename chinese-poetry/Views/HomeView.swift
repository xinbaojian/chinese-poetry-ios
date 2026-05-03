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
    @State private var poems: [Poem] = []

    private var learnedCount: Int { records.count }
    private var dueReviewCount: Int {
        let engine = ReviewEngine()
        return records.filter { engine.isDueForReview(nextReviewDate: $0.nextReviewDate) }.count
    }
    private var totalPoems: Int { poems.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("今日任务")
                            .font(.title2.bold())
                        HStack(spacing: 16) {
                            StatCard(title: "待复习", value: "\(dueReviewCount)", color: .orange)
                            StatCard(title: "已学完", value: "\(learnedCount)", color: .green)
                            StatCard(title: "总共", value: "\(totalPoems)", color: .blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
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
            .onAppear {
                poems = (try? PoemLoader.loadPoems()) ?? []
            }
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
