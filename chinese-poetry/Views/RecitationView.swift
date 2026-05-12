import SwiftUI

struct RecitationView: View {
    let poem: Poem

    @State private var phase = Phase.ready
    @State private var recognizer = SpeechRecognizer()
    @State private var checkResult: RecitationChecker.Result?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case ready, recording, result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    switch phase {
                    case .ready:
                        readyView
                    case .recording:
                        recordingView
                    case .result:
                        if let result = checkResult {
                            resultView(result)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("语音背诵")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text(poem.title)
                .font(.title2.bold())
            Text("\(poem.dynasty) · \(poem.author)")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ready

    private var readyView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("点击下方按钮开始背诵\n系统将自动识别你的语音")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Button(action: startRecitation) {
                Label("开始背诵", systemImage: "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 300)
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: 20) {
            PulsingMic()

            Text("正在聆听...")
                .font(.headline)
                .foregroundStyle(.secondary)

            if !recognizer.recognizedText.isEmpty {
                Text(recognizer.recognizedText)
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: stopRecitation) {
                Label("停止背诵", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Result

    private func resultView(_ result: RecitationChecker.Result) -> some View {
        VStack(spacing: 24) {
            resultSummary(result)

            let grouped = groupByLines(result)
            VStack(alignment: .center, spacing: 20) {
                ForEach(Array(grouped.enumerated()), id: \.offset) { _, lineChars in
                    if !lineChars.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(Array(lineChars.enumerated()), id: \.offset) { _, item in
                                charCard(item)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 16) {
                Button(action: retry) {
                    Label("再背一次", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: { dismiss() }) {
                    Label("完成", systemImage: "checkmark")
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func resultSummary(_ result: RecitationChecker.Result) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(result.accuracy * 100))%")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(result.accuracy >= 0.8 ? .green : result.accuracy >= 0.5 ? .orange : .red)

            Text("\(result.correctCount)/\(result.correctCount + result.wrongCount + result.missingCount) 字正确")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func charCard(_ item: RecitationChecker.AlignedChar) -> some View {
        let color: Color = switch item.status {
        case .correct: .green
        case .wrong: .red
        case .missing: .orange
        case .extra: .gray
        }

        VStack(spacing: 2) {
            let displayChar = item.original ?? item.recognized ?? ""
            if let py = PinyinHelper.pinyin(for: displayChar) {
                Text(PinyinHelper.stripTone(py))
                    .font(.system(size: 9))
                    .foregroundStyle(color.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text(" ").font(.system(size: 9))
            }

            Text(displayChar)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(color)

            Image(systemName: item.status == .correct ? "checkmark" : item.status == .missing ? "minus" : "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 36, height: 54)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.2), lineWidth: 0.5))
    }

    // MARK: - Line Grouping

    private func groupByLines(_ result: RecitationChecker.Result) -> [[RecitationChecker.AlignedChar]] {
        var lineEndIndices: [Int] = []
        var count = 0
        for line in poem.displayLines {
            let lineChinese = line.unicodeScalars.filter {
                ($0.value >= 0x4E00 && $0.value <= 0x9FFF) || ($0.value >= 0x3400 && $0.value <= 0x4DBF)
            }.count
            count += lineChinese
            lineEndIndices.append(count)
        }

        func lineFor(idx: Int) -> Int {
            for (lineIdx, end) in lineEndIndices.enumerated() {
                if idx < end { return lineIdx }
            }
            return max(lineEndIndices.count - 1, 0)
        }

        var lines: [[RecitationChecker.AlignedChar]] = poem.displayLines.map { _ in [] }
        var originalIdx = 0

        for item in result.alignedChars {
            if item.original != nil {
                lines[lineFor(idx: originalIdx)].append(item)
                originalIdx += 1
            } else {
                let target = originalIdx > 0 ? lineFor(idx: originalIdx - 1) : 0
                lines[target].append(item)
            }
        }

        return lines
    }

    // MARK: - Actions

    private func startRecitation() {
        errorMessage = nil
        Task {
            let authorized = await recognizer.requestAuthorization()
            guard authorized else {
                errorMessage = "需要麦克风和语音识别权限，请在系统设置中开启"
                return
            }
            do {
                try recognizer.start(contextualStrings: poem.paragraphs)
                phase = .recording
            } catch {
                errorMessage = "语音识别不可用，请检查设备是否支持"
            }
        }
    }

    private func stopRecitation() {
        recognizer.stop()
        if recognizer.recognizedText.isEmpty {
            errorMessage = "未检测到语音，请重试"
            phase = .ready
            return
        }
        let result = RecitationChecker.check(
            original: poem.paragraphs.joined(),
            recognized: recognizer.recognizedText,
            headerToSkip: "\(poem.title)\(poem.dynasty)\(poem.author)"
        )
        checkResult = result
        phase = .result
    }

    private func retry() {
        recognizer.stop()
        recognizer = SpeechRecognizer()
        checkResult = nil
        errorMessage = nil
        phase = .ready
    }
}

// MARK: - Pulsing Mic Animation

private struct PulsingMic: View {
    @State private var isPulsing = false

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 50))
            .foregroundStyle(.red)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
