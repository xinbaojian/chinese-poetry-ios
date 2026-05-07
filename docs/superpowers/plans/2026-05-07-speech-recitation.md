# 语音背诵识别功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在复习页面新增语音背诵模式，通过 SFSpeechRecognizer 实时识别语音，拼音级别对比原诗，逐字卡片展示结果。

**Architecture:** 3 个新文件（SpeechRecognizer、RecitationChecker、RecitationView），复用现有 PinyinHelper 和 FlowLayout。RecitationChecker 使用 Levenshtein 编辑距离做拼音对齐，忽略声调。UI 以 Sheet 弹窗形式从 ReviewView 进入。

**Tech Stack:** SwiftUI, Speech framework (SFSpeechRecognizer), AVFoundation, Swift Testing

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `chinese-poetry/Services/PinyinHelper.swift` | 新增 `pinyin(for:)` 和 `stripTone(_:)` |
| Create | `chinese-poetry/Services/RecitationChecker.swift` | 拼音级别对比算法 |
| Create | `chinese-poetry/Services/SpeechRecognizer.swift` | 语音识别管理器 |
| Create | `chinese-poetry/Views/RecitationView.swift` | 背诵页面 UI |
| Modify | `chinese-poetry/Views/ReviewView.swift` | 添加入口按钮和 Sheet |
| Modify | `chinese-poetry.xcodeproj/project.pbxproj` | 添加隐私权限描述 |
| Create | `chinese-poetryTests/RecitationCheckerTests.swift` | 对比算法测试 |

**注：** 项目使用 `PBXFileSystemSynchronizedRootGroup`，在 `chinese-poetry/` 和 `chinese-poetryTests/` 目录下创建 .swift 文件会自动被 Xcode 发现，无需手动编辑 pbxproj 添加源文件引用。

---

## Task 1: PinyinHelper Enhancement

**Files:**
- Modify: `chinese-poetry/Services/PinyinHelper.swift`
- Create: `chinese-poetryTests/PinyinHelperTests.swift`

- [ ] **Step 1: Add `pinyin(for:)` and `stripTone(_:)` to PinyinHelper**

在 `PinyinHelper.swift` 文件末尾（`}` 之前）添加：

```swift
/// 获取单个汉字的拼音（应用多音字修正），非汉字返回 nil
static func pinyin(for char: String) -> String? {
    if let corrected = corrections[char] {
        return corrected
    }
    return toPinyin(char)
}

/// 去掉拼音声调标记，仅保留声母+韵母
static func stripTone(_ pinyin: String) -> String {
    let mutable = NSMutableString(string: pinyin)
    CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
    return (mutable as String).lowercased()
}
```

- [ ] **Step 2: Create PinyinHelperTests.swift**

```swift
import Testing
import Foundation
@testable import chinese_poetry

struct PinyinHelperTests {
    @Test("stripTone 去除声调标记")
    func stripToneRemovesDiacritics() async {
        #expect(await PinyinHelper.stripTone("chuáng") == "chuang")
        #expect(await PinyinHelper.stripTone("qián") == "qian")
        #expect(await PinyinHelper.stripTone("guāng") == "guang")
        #expect(await PinyinHelper.stripTone("guǎng") == "guang")
    }

    @Test("pinyin 返回汉字拼音")
    func pinyinReturnsPinyin() async {
        let result = await PinyinHelper.pinyin(for: "床")
        #expect(result != nil)
    }

    @Test("pinyin 应用多音字修正")
    func pinyinAppliesCorrections() async {
        #expect(await PinyinHelper.pinyin(for: "还") == "hái")
        #expect(await PinyinHelper.pinyin(for: "重") == "chóng")
    }
}
```

- [ ] **Step 3: Run tests to verify**

Run: `xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add chinese-poetry/Services/PinyinHelper.swift chinese-poetryTests/PinyinHelperTests.swift
git commit -m "feat: add pinyin(for:) and stripTone() to PinyinHelper"
```

---

## Task 2: RecitationChecker

**Files:**
- Create: `chinese-poetry/Services/RecitationChecker.swift`
- Create: `chinese-poetryTests/RecitationCheckerTests.swift`

- [ ] **Step 1: Create test file with failing tests**

```swift
import Testing
import Foundation
@testable import chinese_poetry

struct RecitationCheckerTests {
    @Test("完美匹配返回100%正确率")
    func perfectMatch() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前明月光"
        )
        #expect(result.accuracy == 1.0)
        #expect(result.correctCount == 5)
        #expect(result.wrongCount == 0)
        #expect(result.missingCount == 0)
        #expect(result.extraCount == 0)
    }

    @Test("错字被标记为wrong")
    func wrongCharacter() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前明月亮"
        )
        #expect(result.accuracy == 0.8)
        #expect(result.correctCount == 4)
        #expect(result.wrongCount == 1)
        #expect(result.alignedChars.filter { $0.status == .wrong }.count == 1)
    }

    @Test("漏字被标记为missing")
    func missingCharacter() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前月光"
        )
        #expect(result.correctCount == 4)
        #expect(result.missingCount == 1)
        #expect(result.accuracy == 0.8)
    }

    @Test("多字被标记为extra")
    func extraCharacter() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前明月大光"
        )
        #expect(result.correctCount == 5)
        #expect(result.extraCount == 1)
        #expect(result.accuracy == 1.0)
    }

    @Test("声调不同视为正确")
    func toneTolerance() async {
        // 光 guāng vs 广 guǎng — 声调不同但声母韵母相同
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前明月广"
        )
        #expect(result.accuracy == 1.0)
        #expect(result.correctCount == 5)
    }

    @Test("完全无关内容返回0%正确率")
    func completelyWrong() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "天地玄黄宇宙洪荒"
        )
        #expect(result.accuracy == 0.0)
    }

    @Test("空识别结果")
    func emptyRecognized() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: ""
        )
        #expect(result.accuracy == 0.0)
        #expect(result.missingCount == 5)
    }

    @Test("标点符号被忽略")
    func punctuationIgnored() async {
        let result = await RecitationChecker.check(
            original: "床前明月光，疑是地上霜。",
            recognized: "床前明月光疑是地上霜"
        )
        #expect(result.accuracy == 1.0)
        #expect(result.correctCount == 10)
    }

    @Test("多错误混合场景")
    func mixedErrors() async {
        // 原诗: 床前明月光 (5字)
        // 识别: 床前月大光 (5字，明→missing，插入大→extra)
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前月大光"
        )
        #expect(result.missingCount >= 1)
        #expect(result.extraCount >= 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:chinese-poetryTests/RecitationCheckerTests test 2>&1 | tail -20`
Expected: FAIL — `RecitationChecker` type not found

- [ ] **Step 3: Create RecitationChecker.swift**

```swift
import Foundation

struct RecitationChecker {
    enum CharStatus: Sendable {
        case correct
        case wrong
        case missing
        case extra
    }

    struct AlignedChar: Sendable {
        let original: String?
        let recognized: String?
        let status: CharStatus
    }

    struct Result: Sendable {
        let alignedChars: [AlignedChar]
        let accuracy: Double
        let correctCount: Int
        let wrongCount: Int
        let missingCount: Int
        let extraCount: Int
    }

    static func check(original: String, recognized: String) -> Result {
        let origChars = filterChinese(original)
        let recChars = filterChinese(recognized)

        let origPinyin = origChars.map { PinyinHelper.stripTone(PinyinHelper.pinyin(for: $0) ?? $0) }
        let recPinyin = recChars.map { PinyinHelper.stripTone(PinyinHelper.pinyin(for: $0) ?? $0) }

        let ops = align(origPinyin, recPinyin)

        var alignedChars: [AlignedChar] = []
        var correctCount = 0, wrongCount = 0, missingCount = 0, extraCount = 0

        for op in ops {
            switch op {
            case .match(let oi, let ri):
                alignedChars.append(AlignedChar(original: origChars[oi], recognized: recChars[ri], status: .correct))
                correctCount += 1
            case .substitute(let oi, let ri):
                alignedChars.append(AlignedChar(original: origChars[oi], recognized: recChars[ri], status: .wrong))
                wrongCount += 1
            case .delete(let oi):
                alignedChars.append(AlignedChar(original: origChars[oi], recognized: nil, status: .missing))
                missingCount += 1
            case .insert(let ri):
                alignedChars.append(AlignedChar(original: nil, recognized: recChars[ri], status: .extra))
                extraCount += 1
            }
        }

        let total = correctCount + wrongCount + missingCount
        let accuracy = total > 0 ? Double(correctCount) / Double(total) : 0

        return Result(
            alignedChars: alignedChars,
            accuracy: accuracy,
            correctCount: correctCount,
            wrongCount: wrongCount,
            missingCount: missingCount,
            extraCount: extraCount
        )
    }

    // MARK: - Private

    private enum Op {
        case match(Int, Int)
        case substitute(Int, Int)
        case delete(Int)
        case insert(Int)
    }

    private static func filterChinese(_ text: String) -> [String] {
        text.unicodeScalars.filter {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
            ($0.value >= 0x3400 && $0.value <= 0x4DBF)
        }.map { String($0) }
    }

    private static func align(_ original: [String], _ recognized: [String]) -> [Op] {
        let n = original.count
        let m = recognized.count

        if n == 0 && m == 0 { return [] }
        if n == 0 { return recognized.indices.map { .insert($0) } }
        if m == 0 { return original.indices.map { .delete($0) } }

        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                if original[i - 1] == recognized[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(
                        dp[i - 1][j] + 1,
                        dp[i][j - 1] + 1,
                        dp[i - 1][j - 1] + 1
                    )
                }
            }
        }

        var ops: [Op] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && original[i - 1] == recognized[j - 1] && dp[i][j] == dp[i - 1][j - 1] {
                ops.append(.match(i - 1, j - 1))
                i -= 1; j -= 1
            } else if i > 0 && dp[i][j] == dp[i - 1][j] + 1 {
                ops.append(.delete(i - 1))
                i -= 1
            } else if j > 0 && dp[i][j] == dp[i][j - 1] + 1 {
                ops.append(.insert(j - 1))
                j -= 1
            } else {
                ops.append(.substitute(i - 1, j - 1))
                i -= 1; j -= 1
            }
        }

        return ops.reversed()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -20`
Expected: All RecitationCheckerTests pass

- [ ] **Step 5: Commit**

```bash
git add chinese-poetry/Services/RecitationChecker.swift chinese-poetryTests/RecitationCheckerTests.swift
git commit -m "feat: add RecitationChecker with pinyin-based comparison"
```

---

## Task 3: SpeechRecognizer

**Files:**
- Create: `chinese-poetry/Services/SpeechRecognizer.swift`

- [ ] **Step 1: Create SpeechRecognizer.swift**

```swift
import Speech
import AVFoundation
import SwiftUI

@Observable
final class SpeechRecognizer {
    var recognizedText = ""
    var isRecording = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var silenceTask: Task<Void, Never>?
    private var lastSpeechTime = Date()

    var isAvailable: Bool {
        guard let sr = speechRecognizer else { return false }
        return sr.isEnabled
    }

    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        guard speechRecognizer != nil else { return false }

        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { return false }

        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        return micGranted
    }

    func start(contextualStrings: [String]) throws {
        guard let speechRecognizer else { return }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualStrings
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.recognizedText = result.bestTranscription.formattedString
                    self.lastSpeechTime = Date()
                }
            }
        }

        isRecording = true
        lastSpeechTime = Date()
        startSilenceDetection()
    }

    func stop() {
        silenceTask?.cancel()
        silenceTask = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    private func startSilenceDetection() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isRecording else { return }
                if Date().timeIntervalSince(self.lastSpeechTime) >= 5.0 {
                    self.stop()
                    return
                }
            }
        }
    }

    deinit {
        stop()
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add chinese-poetry/Services/SpeechRecognizer.swift
git commit -m "feat: add SpeechRecognizer with silence detection"
```

---

## Task 4: RecitationView

**Files:**
- Create: `chinese-poetry/Views/RecitationView.swift`

- [ ] **Step 1: Create RecitationView.swift**

```swift
import SwiftUI

struct RecitationView: View {
    let poem: Poem
    let onComplete: () -> Void

    @State private var phase = Phase.ready
    @State private var recognizer = SpeechRecognizer()
    @State private var checkResult: RecitationChecker.Result?
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
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("点击下方按钮开始背诵\n系统将自动识别你的语音")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(action: startRecitation) {
                Label("开始背诵", systemImage: "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
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
        VStack(spacing: 20) {
            resultSummary(result)

            characterGrid(result)

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

    private func characterGrid(_ result: RecitationChecker.Result) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(result.alignedChars.enumerated()), id: \.offset) { _, item in
                charCard(item)
            }
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
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Actions

    private func startRecitation() {
        Task {
            let authorized = await recognizer.requestAuthorization()
            guard authorized else { return }
            do {
                try recognizer.start(contextualStrings: poem.paragraphs)
                phase = .recording
            } catch {
                // Handle error silently - user can retry
            }
        }
    }

    private func stopRecitation() {
        recognizer.stop()
        let result = RecitationChecker.check(
            original: poem.paragraphs.joined(),
            recognized: recognizer.recognizedText
        )
        checkResult = result
        phase = .result
    }

    private func retry() {
        recognizer.stop()
        recognizer = SpeechRecognizer()
        checkResult = nil
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
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add chinese-poetry/Views/RecitationView.swift
git commit -m "feat: add RecitationView with recording and result display"
```

---

## Task 5: ReviewView Integration + Permissions

**Files:**
- Modify: `chinese-poetry/Views/ReviewView.swift`
- Modify: `chinese-poetry.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add state variable to ReviewView**

在 `ReviewView` 的 `@State` 变量区域（约第 9 行附近）添加：

```swift
@State private var showingRecitation = false
```

- [ ] **Step 2: Add recitation button to reviewContent**

在 `reviewContent` 的 `HStack` 中（约第 78 行），在"遮挡自测"和"完成复习"按钮之间添加语音背诵按钮：

在 `Button(isHidden ? "显示原文" : "遮挡自测") { ... }` 闭包之后、`Button("完成复习") { ... }` 之前，添加：

```swift
Button(action: { showingRecitation = true }) {
    Label("语音背诵", systemImage: "mic.fill")
}
.font(.headline)
.padding()
.background(Color.purple.opacity(0.15))
.foregroundStyle(.purple)
.clipShape(RoundedRectangle(cornerRadius: 10))
```

- [ ] **Step 3: Add sheet modifier**

在 `reviewContent` 的 `.sheet(item: $reviewingRecord)` 之前添加：

```swift
.sheet(isPresented: $showingRecitation) {
    if currentIndex < dueRecords.count,
       let poem = poemMap[dueRecords[currentIndex].poemId] {
        RecitationView(poem: poem, onComplete: { showingRecitation = false })
    }
}
```

- [ ] **Step 4: Add privacy permission keys to pbxproj**

在 `project.pbxproj` 的 Debug 配置（`1DF5A4642FA72F2E00AE7D97 /* Debug */`）的 buildSettings 中，在 `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` 行之后添加：

```
INFOPLIST_KEY_NSMicrophoneUsageDescription = "需要使用麦克风录制您的背诵语音";
INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "需要语音识别来对比您的背诵是否正确";
```

同样在 Release 配置（`1DF5A4652FA72F2E00AE7D97 /* Release */`）的对应位置添加相同的两行。

- [ ] **Step 5: Build to verify**

Run: `xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Run all tests**

Run: `xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add chinese-poetry/Views/ReviewView.swift chinese-poetry.xcodeproj/project.pbxproj
git commit -m "feat: integrate speech recitation into ReviewView with permissions"
```
