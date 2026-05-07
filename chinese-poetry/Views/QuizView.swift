import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var poems: [Poem] = []
    @State private var quizPoems: [Poem] = []
    @State private var currentIndex = 0
    @State private var showContent = false
    @State private var showTranslation = false
    @State private var quizStarted = false
    @State private var correctCount = 0
    @State private var quizFinished = false

    private let maxQuestions = 10

    private var poemMap: [String: Poem] {
        Dictionary(uniqueKeysWithValues: poems.map { ($0.id, $0) })
    }

    private var learnedPoems: [Poem] {
        records.compactMap { poemMap[$0.poemId] }
    }

    var body: some View {
        Group {
                if !quizStarted {
                    startScreen
                } else if quizFinished {
                    resultScreen
                } else {
                    quizScreen
                }
            }
            .navigationTitle("测验")
            .onAppear {
                poems = (try? PoemLoader.loadPoems()) ?? []
            }
    }

    // MARK: - 开始页

    private var startScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "questionmark.circle")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("随机测验")
                    .font(.title.bold())
                Text("从已学习诗词中随机抽题")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                StatRow(label: "已学习", value: "\(learnedPoems.count) 首")
                StatRow(label: "抽题数量", value: "\(min(maxQuestions, learnedPoems.count)) 首")
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                startQuiz()
            } label: {
                Label("开始测验", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(learnedPoems.isEmpty ? Color.gray : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(learnedPoems.isEmpty)

            if learnedPoems.isEmpty {
                Text("请先去诗词库加入学习计划")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - 测验中

    private var quizScreen: some View {
        let poem = quizPoems[currentIndex]
        return VStack(spacing: 20) {
            ProgressView(value: Double(currentIndex + 1), total: Double(quizPoems.count))
                .tint(.blue)
            Text("第 \(currentIndex + 1) / \(quizPoems.count) 题")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(poem.title)
                            .font(.title.bold())

                        if showContent {
                            Text("\(poem.dynasty) · \(poem.author)")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("？· ？？？")
                                .font(.title3)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    VStack(spacing: 14) {
                        ForEach(poem.displayLines, id: \.self) { line in
                            Text(showContent ? line : String(repeating: "＿＿", count: max(1, min(line.count, 6))))
                                .font(.title2)
                                .foregroundStyle(showContent ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    if showContent, let translation = poem.translation {
                        DisclosureGroup("查看释义", isExpanded: $showTranslation) {
                            Text(translation)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        .font(.subheadline)
                    }
                }
            }

            Spacer()

            if !showContent {
                Button {
                    withAnimation { showContent = true }
                } label: {
                    Label("显示原文", systemImage: "eye.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                HStack(spacing: 12) {
                    Button {
                        answer(correct: false)
                    } label: {
                        Label("不熟练", systemImage: "xmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        answer(correct: true)
                    } label: {
                        Label("熟练", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - 结果页

    private var resultScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: correctCount == quizPoems.count ? "trophy.fill" : "star.fill")
                .font(.system(size: 72))
                .foregroundStyle(.yellow)

            Text("测验完成")
                .font(.title.bold())

            VStack(spacing: 12) {
                StatRow(label: "正确", value: "\(correctCount) 首")
                StatRow(label: "错误", value: "\(quizPoems.count - correctCount) 首")
                StatRow(label: "正确率", value: quizPoems.isEmpty ? "0%" : "\(correctCount * 100 / quizPoems.count)%")
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                resetQuiz()
            } label: {
                Label("再来一次", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func startQuiz() {
        let pool = learnedPoems.shuffled()
        quizPoems = Array(pool.prefix(maxQuestions))
        currentIndex = 0
        correctCount = 0
        showContent = false
        showTranslation = false
        quizStarted = true
        quizFinished = false
    }

    private func answer(correct: Bool) {
        if correct { correctCount += 1 }
        if currentIndex + 1 >= quizPoems.count {
            quizFinished = true
        } else {
            currentIndex += 1
            showContent = false
            showTranslation = false
        }
    }

    private func resetQuiz() {
        quizStarted = false
        quizFinished = false
        currentIndex = 0
        correctCount = 0
        showContent = false
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    QuizView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
