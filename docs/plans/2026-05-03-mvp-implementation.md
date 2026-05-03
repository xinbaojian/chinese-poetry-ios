# 儿童古诗词背诵 App MVP 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个帮助小学生通过艾宾浩斯记忆曲线背诵古诗词的纯本地 iOS App。

**Architecture:** SwiftUI + SwiftData，单 Target Xcode 项目。诗词数据以 JSON Bundle 内置，学习记录用 SwiftData 本地持久化。复习引擎纯算法驱动，UI 采用 5 Tab 结构。

**Tech Stack:** SwiftUI, SwiftData, UserNotifications, Swift Testing

**Note:** 项目使用 `PBXFileSystemSynchronizedRootGroup`，新建文件放入 `chinese-poetry/` 目录后 Xcode 自动识别，无需手动修改 `.pbxproj`。

---

## 目录结构（实现后）

```
chinese-poetry/
├── Models/
│   ├── Poem.swift
│   ├── MasteryLevel.swift
│   └── LearningRecord.swift
├── Services/
│   ├── PoemLoader.swift
│   ├── ReviewEngine.swift
│   └── NotificationManager.swift
├── Views/
│   ├── HomeView.swift
│   ├── PoemLibraryView.swift
│   ├── PoemDetailView.swift
│   ├── LearnView.swift
│   ├── ReviewView.swift
│   └── SettingsView.swift
├── Resources/
│   └── poems.json
├── Assets.xcassets/
├── chinese_poetryApp.swift
└── ContentView.swift
```

---

### Task 1: 数据模型 — Poem + MasteryLevel

**Files:**
- Create: `chinese-poetry/Models/Poem.swift`
- Create: `chinese-poetry/Models/MasteryLevel.swift`
- Create: `chinese-poetry/Resources/poems.json`（测试用 5 首诗）
- Test: `chinese-poetryTests/PoemTests.swift`

**Step 1: 创建 MasteryLevel 枚举**

```swift
// chinese-poetry/Models/MasteryLevel.swift
import Foundation

enum MasteryLevel: String, Codable, Codable {
    case proficient    // 熟练
    case fair          // 一般
    case weak          // 不熟练
}
```

**Step 2: 创建 Poem 模型**

```swift
// chinese-poetry/Models/Poem.swift
import Foundation

struct Poem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let dynasty: String
    let grade: Int
    let paragraphs: [String]
    let translation: String?
}
```

**Step 3: 创建测试用 poems.json（5 首测试数据）**

```json
[
  {
    "id": "p001",
    "title": "静夜思",
    "author": "李白",
    "dynasty": "唐",
    "grade": 1,
    "paragraphs": ["床前明月光，疑是地上霜。", "举头望明月，低头思故乡。"],
    "translation": "明亮的月光洒在床前，好像地上的一层白霜。抬头望着明月，不禁低下头思念起故乡来。"
  },
  {
    "id": "p002",
    "title": "春晓",
    "author": "孟浩然",
    "dynasty": "唐",
    "grade": 1,
    "paragraphs": ["春眠不觉晓，处处闻啼鸟。", "夜来风雨声，花落知多少。"],
    "translation": "春天的夜晚睡得香甜，不知不觉天就亮了。醒来后到处都能听到鸟叫声。昨夜风雨交加，不知道有多少花瓣被吹落了。"
  },
  {
    "id": "p003",
    "title": "咏鹅",
    "author": "骆宾王",
    "dynasty": "唐",
    "grade": 1,
    "paragraphs": ["鹅，鹅，鹅，曲项向天歌。", "白毛浮绿水，红掌拨清波。"],
    "translation": "大白鹅呀大白鹅，弯着脖子朝天唱歌。白色的羽毛漂浮在绿水上，红色的脚掌拨动着清澈的水波。"
  },
  {
    "id": "p004",
    "title": "登鹳雀楼",
    "author": "王之涣",
    "dynasty": "唐",
    "grade": 2,
    "paragraphs": ["白日依山尽，黄河入海流。", "欲穷千里目，更上一层楼。"],
    "translation": "太阳沿着山峦慢慢落下去了，黄河水滚滚流向大海。想要看到更远的地方，就要再登上一层楼。"
  },
  {
    "id": "p005",
    "title": "望庐山瀑布",
    "author": "李白",
    "dynasty": "唐",
    "grade": 2,
    "paragraphs": ["日照香炉生紫烟，遥看瀑布挂前川。", "飞流直下三千尺，疑是银河落九天。"],
    "translation": "太阳照在香炉峰上，生出了紫色的烟雾。远远望去，瀑布像一条白练挂在山前。水流飞快地直冲下来，好像银河从天上落下来一样。"
  }
]
```

**Step 4: 写 Poem 解码测试**

```swift
// chinese-poetryTests/PoemTests.swift
import Testing
import Foundation

struct PoemTests {

    @Test("解码 poems.json")
    func decodePoems() throws {
        let url = Bundle.main.url(forResource: "poems", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let poems = try JSONDecoder().decode([Poem].self, from: data)
        #expect(poems.count == 5)
        #expect(poems[0].title == "静夜思")
        #expect(poems[0].grade == 1)
        #expect(poems[0].translation != nil)
    }

    @Test("Poem 结构体属性正确")
    func poemProperties() {
        let poem = Poem(
            id: "test", title: "测试", author: "作者",
            dynasty: "唐", grade: 3,
            paragraphs: ["第一句", "第二句"],
            translation: "释义"
        )
        #expect(poem.id == "test")
        #expect(poem.paragraphs.count == 2)
        #expect(poem.translation == "释义")
    }
}
```

**Step 5: 运行测试**

```bash
xcodebuild test -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:chinese-poetryTests/PoemTests 2>&1 | tail -5
```

Expected: **TEST SUCCEEDED**

**Step 6: Commit**

```bash
git add chinese-poetry/Models/ chinese-poetry/Resources/ chinese-poetryTests/PoemTests.swift
git commit -m "feat: add Poem model and test data"
```

---

### Task 2: 数据模型 — LearningRecord（SwiftData）

**Files:**
- Create: `chinese-poetry/Models/LearningRecord.swift`
- Test: `chinese-poetryTests/LearningRecordTests.swift`

**Step 1: 创建 ReviewEntry 和 LearningRecord**

```swift
// chinese-poetry/Models/LearningRecord.swift
import Foundation
import SwiftData

struct ReviewEntry: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let level: MasteryLevel
}

@Model
final class LearningRecord {
    var poemId: String
    var learnedDate: Date
    var nextReviewDate: Date
    var masteryLevel: MasteryLevel
    var reviewCount: Int
    var reviewHistory: [ReviewEntry]

    init(
        poemId: String,
        learnedDate: Date = Date(),
        nextReviewDate: Date,
        masteryLevel: MasteryLevel = .fair,
        reviewCount: Int = 0,
        reviewHistory: [ReviewEntry] = []
    ) {
        self.poemId = poemId
        self.learnedDate = learnedDate
        self.nextReviewDate = nextReviewDate
        self.masteryLevel = masteryLevel
        self.reviewCount = reviewCount
        self.reviewHistory = reviewHistory
    }
}
```

**Step 2: 写 LearningRecord 测试**

```swift
// chinese-poetryTests/LearningRecordTests.swift
import Testing
import Foundation
import SwiftData

struct LearningRecordTests {

    @Test("创建 LearningRecord 默认值正确")
    func createRecord() {
        let record = LearningRecord(
            poemId: "p001",
            nextReviewDate: Date().addingTimeInterval(86400)
        )
        #expect(record.poemId == "p001")
        #expect(record.reviewCount == 0)
        #expect(record.reviewHistory.isEmpty)
        #expect(record.masteryLevel == .fair)
    }

    @Test("LearningRecord 可插入 ModelContainer")
    func insertIntoContainer() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LearningRecord.self, configurations: config
        )
        let context = container.mainContext
        let record = LearningRecord(
            poemId: "p001",
            nextReviewDate: Date()
        )
        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<LearningRecord>()
        let records = try context.fetch(descriptor)
        #expect(records.count == 1)
        #expect(records[0].poemId == "p001")
    }
}
```

**Step 3: 运行测试**

```bash
xcodebuild test -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:chinese-poetryTests/LearningRecordTests 2>&1 | tail -5
```

Expected: **TEST SUCCEEDED**

**Step 4: 删除旧的 Item.swift，更新 App 入口的 ModelContainer**

删除 `chinese-poetry/Item.swift`。

更新 `chinese-poetry/chinese_poetryApp.swift`：

```swift
import SwiftUI
import SwiftData

@main
struct chinese_poetryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([LearningRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add LearningRecord model with SwiftData"
```

---

### Task 3: PoemLoader — JSON 数据加载服务

**Files:**
- Create: `chinese-poetry/Services/PoemLoader.swift`
- Test: `chinese-poetryTests/PoemLoaderTests.swift`

**Step 1: 写 PoemLoader 测试**

```swift
// chinese-poetryTests/PoemLoaderTests.swift
import Testing
import Foundation

struct PoemLoaderTests {

    @Test("从 Bundle 加载诗词列表")
    func loadPoems() throws {
        let poems = try PoemLoader.loadPoems()
        #expect(!poems.isEmpty)
    }

    @Test("按年级筛选诗词")
    func filterByGrade() throws {
        let poems = try PoemLoader.loadPoems()
        let grade1 = PoemLoader.filter(poems: poems, byGrade: 1)
        let grade2 = PoemLoader.filter(poems: poems, byGrade: 2)
        #expect(grade1.allSatisfy { $0.grade == 1 })
        #expect(grade2.allSatisfy { $0.grade == 2 })
    }

    @Test("搜索诗词按标题和作者")
    func searchPoems() throws {
        let poems = try PoemLoader.loadPoems()
        let results = PoemLoader.search(poems: poems, query: "李白")
        #expect(results.allSatisfy { $0.author.contains("李白") })
    }
}
```

**Step 2: 实现 PoemLoader**

```swift
// chinese-poetry/Services/PoemLoader.swift
import Foundation

struct PoemLoader {

    static func loadPoems() throws -> [Poem] {
        guard let url = Bundle.main.url(forResource: "poems", withExtension: "json") else {
            throw PoemError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Poem].self, from: data)
    }

    static func filter(poems: [Poem], byGrade grade: Int) -> [Poem] {
        poems.filter { $0.grade == grade }
    }

    static func search(poems: [Poem], query: String) -> [Poem] {
        guard !query.isEmpty else { return poems }
        poems.filter {
            $0.title.contains(query) ||
            $0.author.contains(query) ||
            $0.paragraphs.contains { $0.contains(query) }
        }
    }
}

enum PoemError: Error {
    case fileNotFound
}
```

**Step 3: 运行测试**

```bash
xcodebuild test -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:chinese-poetryTests/PoemLoaderTests 2>&1 | tail -5
```

**Step 4: Commit**

```bash
git add chinese-poetry/Services/PoemLoader.swift chinese-poetryTests/PoemLoaderTests.swift
git commit -m "feat: add PoemLoader service for JSON loading"
```

---

### Task 4: ReviewEngine — 艾宾浩斯复习引擎

**Files:**
- Create: `chinese-poetry/Services/ReviewEngine.swift`
- Test: `chinese-poetryTests/ReviewEngineTests.swift`

**Step 1: 写 ReviewEngine 测试**

```swift
// chinese-poetryTests/ReviewEngineTests.swift
import Testing
import Foundation

struct ReviewEngineTests {

    @Test("熟练等级的复习间隔递增")
    func proficientIntervals() {
        let intervals = ReviewEngine.intervals(for: .proficient)
        #expect(intervals == [1, 2, 4, 7, 15])
    }

    @Test("一般等级的复习间隔缩短")
    func fairIntervals() {
        let intervals = ReviewEngine.intervals(for: .fair)
        #expect(intervals == [1, 1, 2, 4, 7])
    }

    @Test("不熟练等级的复习间隔最短")
    func weakIntervals() {
        let intervals = ReviewEngine.intervals(for: .weak)
        #expect(intervals == [1, 1, 1, 2, 4])
    }

    @Test("首次复习 nextReviewDate 为明天")
    func firstReviewDate() {
        let engine = ReviewEngine()
        let now = Date()
        let nextDate = engine.calculateNextReviewDate(
            reviewCount: 0,
            level: .proficient,
            from: now
        )
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: now, to: nextDate).day
        #expect(diff == 1)
    }

    @Test("第3次熟练复习间隔为4天")
    func thirdReviewInterval() {
        let engine = ReviewEngine()
        let now = Date()
        let nextDate = engine.calculateNextReviewDate(
            reviewCount: 2,
            level: .proficient,
            from: now
        )
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: now, to: nextDate).day
        #expect(diff == 4)
    }

    @Test("复习次数超过间隔数组后使用最后一个值")
    func overflowInterval() {
        let engine = ReviewEngine()
        let now = Date()
        let nextDate = engine.calculateNextReviewDate(
            reviewCount: 10,
            level: .proficient,
            from: now
        )
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: now, to: nextDate).day
        #expect(diff == 15)
    }

    @Test("判断是否到期复习")
    func isDueForReview() {
        let engine = ReviewEngine()
        let yesterday = Date().addingTimeInterval(-86400)
        let tomorrow = Date().addingTimeInterval(86400)
        #expect(engine.isDueForReview(nextReviewDate: yesterday))
        #expect(!engine.isDueForReview(nextReviewDate: tomorrow))
    }
}
```

**Step 2: 实现 ReviewEngine**

```swift
// chinese-poetry/Services/ReviewEngine.swift
import Foundation

struct ReviewEngine {

    static func intervals(for level: MasteryLevel) -> [Int] {
        switch level {
        case .proficient: [1, 2, 4, 7, 15]
        case .fair:       [1, 1, 2, 4, 7]
        case .weak:       [1, 1, 1, 2, 4]
        }
    }

    func calculateNextReviewDate(reviewCount: Int, level: MasteryLevel, from date: Date) -> Date {
        let intervals = Self.intervals(for: level)
        let index = min(reviewCount, intervals.count - 1)
        let days = intervals[index]
        return Calendar.current.date(byAdding: .day, value: days, to: date)!
    }

    func isDueForReview(nextReviewDate: Date) -> Bool {
        nextReviewDate <= Date()
    }
}
```

**Step 3: 运行测试**

```bash
xcodebuild test -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:chinese-poetryTests/ReviewEngineTests 2>&1 | tail -5
```

**Step 4: Commit**

```bash
git add chinese-poetry/Services/ReviewEngine.swift chinese-poetryTests/ReviewEngineTests.swift
git commit -m "feat: add Ebbinghaus review engine with mastery levels"
```

---

### Task 5: NotificationManager — 本地推送通知

**Files:**
- Create: `chinese-poetry/Services/NotificationManager.swift`

**Step 1: 实现 NotificationManager**

```swift
// chinese-poetry/Services/NotificationManager.swift
import Foundation
import UserNotifications

struct NotificationManager {

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleDailyReminder(at hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "古诗词复习提醒"
        content.body = "今天有古诗词需要复习哦，快来背诵吧！"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, repeats: true
        )
        let request = UNNotificationRequest(
            identifier: "daily_review_reminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current()
            .removeAllPendingNotificationRequests()
    }
}
```

**Step 2: Commit**

```bash
git add chinese-poetry/Services/NotificationManager.swift
git commit -m "feat: add NotificationManager for local push notifications"
```

---

### Task 6: App 入口 + Tab 导航

**Files:**
- Modify: `chinese-poetry/chinese_poetryApp.swift`（已在 Task 2 更新）
- Modify: `chinese-poetry/ContentView.swift`

**Step 1: 将 ContentView 改为 TabView 导航**

```swift
// chinese-poetry/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("首页", systemImage: "house.fill") {
                HomeView()
            }
            Tab("诗词库", systemImage: "book.fill") {
                PoemLibraryView()
            }
            Tab("学习", systemImage: "pencil.and.outline") {
                LearnView()
            }
            Tab("复习", systemImage: "arrow.clockwise") {
                ReviewView()
            }
            Tab("设置", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
```

**Step 2: 创建占位 View 文件**

为 5 个 Tab 创建最小 View 占位，确保编译通过：

```swift
// chinese-poetry/Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            Text("首页")
                .navigationTitle("古诗词背诵")
        }
    }
}
```

```swift
// chinese-poetry/Views/PoemLibraryView.swift
import SwiftUI

struct PoemLibraryView: View {
    var body: some View {
        NavigationStack {
            Text("诗词库")
                .navigationTitle("诗词库")
        }
    }
}
```

```swift
// chinese-poetry/Views/LearnView.swift
import SwiftUI

struct LearnView: View {
    var body: some View {
        NavigationStack {
            Text("学习")
                .navigationTitle("学习")
        }
    }
}
```

```swift
// chinese-poetry/Views/ReviewView.swift
import SwiftUI

struct ReviewView: View {
    var body: some View {
        NavigationStack {
            Text("复习")
                .navigationTitle("复习")
        }
    }
}
```

```swift
// chinese-poetry/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("设置")
                .navigationTitle("设置")
        }
    }
}
```

**Step 3: 确认编译通过**

```bash
xcodebuild build -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

Expected: **BUILD SUCCEEDED**

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add TabView navigation with 5 tabs"
```

---

### Task 7: 首页 — HomeView

**Files:**
- Modify: `chinese-poetry/Views/HomeView.swift`

**Step 1: 实现首页**

```swift
// chinese-poetry/Views/HomeView.swift
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
                    // 今日任务卡片
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

                    // 快捷入口
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
```

**Step 2: 确认编译通过**

```bash
xcodebuild build -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add chinese-poetry/Views/HomeView.swift
git commit -m "feat: implement HomeView with daily stats and quick actions"
```

---

### Task 8: 诗词库 — PoemLibraryView + PoemDetailView

**Files:**
- Modify: `chinese-poetry/Views/PoemLibraryView.swift`
- Create: `chinese-poetry/Views/PoemDetailView.swift`

**Step 1: 实现诗词库列表**

```swift
// chinese-poetry/Views/PoemLibraryView.swift
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
                // 年级筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        GradePill(title: "全部", isSelected: selectedGrade == nil) {
                            selectedGrade = nil
                        }
                        ForEach(1...6, id: \.self) { grade in
                            GradePill(
                                title: "\(grade)年级",
                                isSelected: selectedGrade == grade
                            ) {
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
```

**Step 2: 实现诗词详情页**

```swift
// chinese-poetry/Views/PoemDetailView.swift
import SwiftUI
import SwiftData

struct PoemDetailView: View {
    let poem: Poem
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var showTranslation = false

    private var isLearned: Bool {
        records.contains { $0.poemId == poem.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题区
                VStack(alignment: .leading, spacing: 4) {
                    Text(poem.title)
                        .font(.title.bold())
                    Text("\(poem.dynasty) · \(poem.author)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // 诗句
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(poem.paragraphs, id: \.self) { line in
                        Text(line)
                            .font(.title2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)

                // 释义
                if let translation = poem.translation {
                    DisclosureGroup("查看释义", isExpanded: $showTranslation) {
                        Text(translation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                    .font(.headline)
                }

                // 加入学习按钮
                if !isLearned {
                    Button {
                        addToLearning()
                    } label: {
                        Label("加入学习计划", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Label("已加入学习计划", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle(poem.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addToLearning() {
        let engine = ReviewEngine()
        let nextDate = engine.calculateNextReviewDate(
            reviewCount: 0, level: .fair, from: Date()
        )
        let record = LearningRecord(
            poemId: poem.id,
            nextReviewDate: nextDate
        )
        modelContext.insert(record)
    }
}

#Preview {
    NavigationStack {
        PoemDetailView(poem: Poem(
            id: "p001", title: "静夜思", author: "李白",
            dynasty: "唐", grade: 1,
            paragraphs: ["床前明月光，疑是地上霜。", "举头望明月，低头思故乡。"],
            translation: "明亮的月光洒在床前..."
        ))
    }
    .modelContainer(for: LearningRecord.self, inMemory: true)
}
```

**Step 3: 编译验证 + Commit**

```bash
xcodebuild build -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
git add -A
git commit -m "feat: implement poem library with grade filter, search, and detail view"
```

---

### Task 9: 学习模块 — LearnView

**Files:**
- Modify: `chinese-poetry/Views/LearnView.swift`

**Step 1: 实现学习流程**

```swift
// chinese-poetry/Views/LearnView.swift
import SwiftUI
import SwiftData

struct LearnView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var poems: [Poem] = []
    @State private var currentPoemIndex = 0
    @State private var isHidden = false
    @State private var showMasterySheet = false

    @AppStorage("dailyNewLimit") private var dailyNewLimit = 2
    @AppStorage("todayNewCount") private var todayNewCount = 0
    @AppStorage("lastNewDate") private var lastNewDate = ""

    private var unlearnedPoems: [Poem] {
        let learnedIds = Set(records.map(\.poemId))
        return poems.filter { !learnedIds.contains($0.id) }
    }

    private var canLearnMore: Bool {
        todayDateString == lastNewDate ? todayNewCount < dailyNewLimit : true
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            Group {
                if unlearnedPoems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("所有诗词都已加入学习计划")
                            .font(.title3)
                    }
                } else if !canLearnMore {
                    VStack(spacing: 12) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                        Text("今日新学已达上限 (\(dailyNewLimit)首)")
                            .font(.title3)
                        Text("明天继续加油！")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    learnContent
                }
            }
            .navigationTitle("学习")
            .onAppear {
                poems = (try? PoemLoader.loadPoems()) ?? []
                currentPoemIndex = 0
            }
        }
    }

    private var learnContent: some View {
        let poem = unlearnedPoems[min(currentPoemIndex, unlearnedPoems.count - 1)]
        return VStack(spacing: 24) {
            // 进度
            Text("第 \(currentPoemIndex + 1) / \(min(unlearnedPoems.count, dailyNewLimit)) 首")
                .foregroundStyle(.secondary)

            // 诗词标题
            VStack(spacing: 4) {
                Text(poem.title)
                    .font(.title.bold())
                Text("\(poem.dynasty) · \(poem.author)")
                    .foregroundStyle(.secondary)
            }

            // 诗句（可遮挡）
            VStack(spacing: 16) {
                ForEach(poem.paragraphs, id: \.self) { line in
                    Text(isHidden ? String(repeating: "＿", count: line.count) : line)
                        .font(.title2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

            // 操作按钮
            HStack(spacing: 16) {
                Button(isHidden ? "显示原文" : "遮挡自测") {
                    isHidden.toggle()
                }
                .font(.headline)
                .padding()
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("完成背诵") {
                    showMasterySheet = true
                }
                .font(.headline)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showMasterySheet) {
            MasteryPicker(poem: poem, onSelect: { level in
                addRecord(poem: poem, level: level)
                showMasterySheet = false
                if lastNewDate != todayDateString {
                    lastNewDate = todayDateString
                    todayNewCount = 1
                } else {
                    todayNewCount += 1
                }
                currentPoemIndex += 1
                isHidden = false
            })
        }
    }

    private func addRecord(poem: Poem, level: MasteryLevel) {
        let engine = ReviewEngine()
        let nextDate = engine.calculateNextReviewDate(
            reviewCount: 0, level: level, from: Date()
        )
        let record = LearningRecord(
            poemId: poem.id,
            nextReviewDate: nextDate,
            masteryLevel: level
        )
        modelContext.insert(record)
    }
}

struct MasteryPicker: View {
    let poem: Poem
    let onSelect: (MasteryLevel) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(poem.title)
                    .font(.title2.bold())
                Text("这首诗背得怎么样？")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button {
                    onSelect(.proficient)
                } label: {
                    Label("熟练 — 很流利！", systemImage: "star.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onSelect(.fair)
                } label: {
                    Label("一般 — 有些卡壳", systemImage: "star.leadinghalf.filled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onSelect(.weak)
                } label: {
                    Label("不熟练 — 需要多练", systemImage: "star")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationTitle("掌握程度")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    LearnView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
```

**Step 2: 编译验证 + Commit**

```bash
xcodebuild build -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
git add -A
git commit -m "feat: implement LearnView with reading and self-test modes"
```

---

### Task 10: 复习模块 — ReviewView

**Files:**
- Modify: `chinese-poetry/Views/ReviewView.swift`

**Step 1: 实现复习流程**

```swift
// chinese-poetry/Views/ReviewView.swift
import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @State private var poems: [Poem] = []
    @State private var currentIndex = 0
    @State private var isHidden = false
    @State private var showMasterySheet = false

    private let engine = ReviewEngine()

    private var dueRecords: [LearningRecord] {
        records.filter { engine.isDueForReview(nextReviewDate: $0.nextReviewDate) }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    private var poemMap: [String: Poem] {
        Dictionary(uniqueKeysWithValues: poems.map { ($0.id, $0) })
    }

    var body: some View {
        NavigationStack {
            Group {
                if dueRecords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "party.popper")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("今天没有待复习的诗词")
                            .font(.title3)
                        Text("继续加油！")
                            .foregroundStyle(.secondary)
                    }
                } else if currentIndex >= dueRecords.count {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("今日复习全部完成！")
                            .font(.title2.bold())
                    }
                } else {
                    reviewContent
                }
            }
            .navigationTitle("复习")
            .onAppear {
                poems = (try? PoemLoader.loadPoems()) ?? []
            }
        }
    }

    private var reviewContent: some View {
        let record = dueRecords[currentIndex]
        let poem = poemMap[record.poemId]
        return VStack(spacing: 24) {
            Text("第 \(currentIndex + 1) / \(dueRecords.count) 首")
                .foregroundStyle(.secondary)

            if let poem {
                VStack(spacing: 4) {
                    Text(poem.title)
                        .font(.title.bold())
                    Text("\(poem.dynasty) · \(poem.author)")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    ForEach(poem.paragraphs, id: \.self) { line in
                        Text(isHidden ? String(repeating: "＿", count: line.count) : line)
                            .font(.title2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                if let translation = poem.translation {
                    DisclosureGroup("查看释义") {
                        Text(translation)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }

            HStack(spacing: 16) {
                Button(isHidden ? "显示原文" : "遮挡自测") {
                    isHidden.toggle()
                }
                .font(.headline)
                .padding()
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("完成复习") {
                    showMasterySheet = true
                }
                .font(.headline)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showMasterySheet) {
            if let poem = poemMap[record.poemId] {
                MasteryPicker(poem: poem) { level in
                    updateRecord(record, level: level)
                    showMasterySheet = false
                    currentIndex += 1
                    isHidden = false
                }
            }
        }
    }

    private func updateRecord(_ record: LearningRecord, level: MasteryLevel) {
        record.masteryLevel = level
        record.reviewCount += 1
        record.reviewHistory.append(ReviewEntry(date: Date(), level: level))
        record.nextReviewDate = engine.calculateNextReviewDate(
            reviewCount: record.reviewCount,
            level: level,
            from: Date()
        )
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
```

**Step 2: 编译验证 + Commit**

```bash
xcodebuild build -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
git add -A
git commit -m "feat: implement ReviewView with Ebbinghaus cycle tracking"
```

---

### Task 11: 设置模块 — SettingsView

**Files:**
- Modify: `chinese-poetry/Views/SettingsView.swift`

**Step 1: 实现设置页**

```swift
// chinese-poetry/Views/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @AppStorage("dailyNewLimit") private var dailyNewLimit = 2
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 9
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // 学习设置
                Section("学习设置") {
                    Stepper("每日新学上限：\(dailyNewLimit) 首", value: $dailyNewLimit, in: 1...3)
                }

                // 复习提醒
                Section("复习提醒") {
                    Toggle("开启每日提醒", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    _ = try? await NotificationManager.requestAuthorization()
                                    NotificationManager.scheduleDailyReminder(
                                        at: reminderHour, minute: reminderMinute
                                    )
                                }
                            } else {
                                NotificationManager.cancelDailyReminder()
                            }
                        }

                    if reminderEnabled {
                        DatePicker(
                            "提醒时间",
                            hour: $reminderHour,
                            minute: $reminderMinute
                        )
                        .onChange(of: reminderHour) { _, _ in scheduleReminder() }
                        .onChange(of: reminderMinute) { _, _ in scheduleReminder() }
                    }
                }

                // 数据管理
                Section("数据管理") {
                    HStack {
                        Text("已学习诗词")
                        Spacer()
                        Text("\(records.count) 首")
                            .foregroundStyle(.secondary)
                    }

                    Button("重置单首诗词进度", role: .destructive) {
                        // TODO: 弹出选择器重置指定诗词
                    }

                    Button("清空所有学习进度", role: .destructive) {
                        showResetAlert = true
                    }
                }
            }
            .navigationTitle("设置")
            .alert("确认清空？", isPresented: $showResetAlert) {
                Button("清空", role: .destructive) {
                    clearAllRecords()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清空后所有学习进度将丢失，此操作不可恢复。")
            }
        }
    }

    private func scheduleReminder() {
        if reminderEnabled {
            NotificationManager.scheduleDailyReminder(
                at: reminderHour, minute: reminderMinute
            )
        }
    }

    private func clearAllRecords() {
        do {
            try modelContext.delete(model: LearningRecord.self)
        } catch {
            // 静默处理
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
```

**Step 2: 编译验证 + Commit**

```bash
xcodebuild build -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
git add -A
git commit -m "feat: implement SettingsView with daily limit and notification config"
```

---

### Task 12: 整理完整诗词数据集

**Files:**
- Replace: `chinese-poetry/Resources/poems.json`（从 5 首扩展到部编版完整数据集）

**Step 1:** 从 chinese-poetry 仓库和教育部部编版小学必背古诗标准，整理完整的 70-80 首诗词 JSON 文件。每首包含 `id`、`title`、`author`、`dynasty`、`grade`（1-6）、`paragraphs`、`translation`（儿童版释义）。

**Step 2: 验证数据格式正确**

```swift
// 在 PoemTests 中添加
@Test("完整诗词数据加载验证")
func loadFullDataset() throws {
    let poems = try PoemLoader.loadPoems()
    #expect(poems.count >= 70)
    // 验证每个年级都有诗词
    for grade in 1...6 {
        let gradePoems = PoemLoader.filter(poems: poems, byGrade: grade)
        #expect(!gradePoems.isEmpty)
    }
    // 验证所有诗词都有必要字段
    for poem in poems {
        #expect(!poem.title.isEmpty)
        #expect(!poem.author.isEmpty)
        #expect(!poem.paragraphs.isEmpty)
    }
}
```

**Step 3: Commit**

```bash
git add chinese-poetry/Resources/poems.json chinese-poetryTests/PoemTests.swift
git commit -m "feat: add complete primary school poetry dataset"
```

---

### Task 13: 全量构建验证 + 清理

**Step 1: 全量编译**

```bash
xcodebuild build -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

**Step 2: 运行全部测试**

```bash
xcodebuild test -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
```

**Step 3: 清理未使用的模板代码**

- 确认 `Item.swift` 已删除
- 确认 `chinese_poetryUITests` 中的模板测试更新

**Step 4: 最终 Commit**

```bash
git add -A
git commit -m "chore: final cleanup and verification"
```
