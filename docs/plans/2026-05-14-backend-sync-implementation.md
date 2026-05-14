# 后端同步改造实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将古诗词 App 从纯本地改为从后端 API 读取诗词数据并同步学习进度到云端。

**Architecture:** 新增 APIClient / AuthService / SyncService 三个网络层，改造 Poem / LearningRecord / MasteryLevel 数据模型对齐后端，改造所有 View 适配新字段名，新增 AuthView 登录注册页。在线优先 + 离线缓存策略。

**Tech Stack:** SwiftUI, SwiftData, URLSession, Keychain, @AppStorage

---

## 任务概览

共 17 个任务，分 5 个阶段：

| 阶段 | 任务 | 说明 |
|------|------|------|
| 一 | 1-4 | 数据模型层改造（Poem, MasteryLevel, LearningRecord, ReviewEngine） |
| 二 | 5-7 | 网络层（APIClient, AuthService, AuthView） |
| 三 | 8-9 | 诗词加载 + 同步层（PoemLoader, SyncService） |
| 四 | 10-15 | View 层适配（所有页面） |
| 五 | 16-17 | App 入口 + 备份 + 编译验证 |

---

### Task 1: 改造 Poem 模型对齐后端

**Files:**
- Modify: `chinese-poetry/Models/Poem.swift`

**Step 1: 修改 Poem struct**

将 `Poem` 的字段完全对齐后端 API 的 `PoemItem`：

- `id: String` → `id: UInt64`
- `author: String` → `poetName: String`
- `grade: Int` → `grade: UInt8`
- `paragraphs: [String]` → `content: String`（JSON 字符串）
- 新增 `var paragraphs: [String]` 计算属性从 content 解析

```swift
import Foundation

struct Poem: Codable, Identifiable, Hashable {
    let id: UInt64
    let title: String
    let poetName: String
    let dynasty: String
    let category: String
    let grade: UInt8
    let content: String
    let translation: String?

    var paragraphs: [String] {
        guard let data = content.data(using: .utf8),
              let lines = try? JSONDecoder().decode([String].self, from: data) else {
            return [content]
        }
        return lines
    }

    var displayLines: [String] {
        paragraphs.flatMap { line in
            var result: [String] = []
            var current = ""
            for char in line {
                current.append(char)
                if "，。！？；".contains(char) {
                    result.append(current)
                    current = ""
                }
            }
            if !current.isEmpty {
                result.append(current)
            }
            return result.isEmpty && current.isEmpty ? [line] : result
        }
    }
}
```

**Step 2: 编译验证**

```bash
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -20
```

预期：编译失败（其他文件还在引用旧字段名），这是正常的，后续任务会逐一修复。

---

### Task 2: 改造 MasteryLevel 为四级

**Files:**
- Modify: `chinese-poetry/Models/MasteryLevel.swift`

**Step 1: 改为四级枚举**

```swift
import Foundation

enum MasteryLevel: String, Codable, CaseIterable {
    case new        // 未学
    case learning   // 学习中
    case reviewing  // 复习中
    case mastered   // 已掌握
}
```

---

### Task 3: 改造 LearningRecord SwiftData 模型

**Files:**
- Modify: `chinese-poetry/Models/LearningRecord.swift`

**Step 1: 增加后端字段**

在现有字段基础上增加 `remoteId`, `poemTitle`, `poetName`, `updatedAt`，并将 `poemId` 改为 `UInt64`：

```swift
import Foundation
import SwiftData

struct ReviewEntry: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let level: MasteryLevel
}

@Model
final class LearningRecord {
    var remoteId: UInt64?
    var poemId: UInt64
    var poemTitle: String
    var poetName: String
    var learnedDate: Date
    var nextReviewDate: Date
    var masteryLevel: MasteryLevel
    var reviewCount: Int
    var updatedAt: Date
    var reviewHistory: [ReviewEntry]

    init(
        remoteId: UInt64? = nil,
        poemId: UInt64,
        poemTitle: String = "",
        poetName: String = "",
        learnedDate: Date = Date(),
        nextReviewDate: Date,
        masteryLevel: MasteryLevel = .learning,
        reviewCount: Int = 0,
        updatedAt: Date = Date(),
        reviewHistory: [ReviewEntry] = []
    ) {
        self.remoteId = remoteId
        self.poemId = poemId
        self.poemTitle = poemTitle
        self.poetName = poetName
        self.learnedDate = learnedDate
        self.nextReviewDate = nextReviewDate
        self.masteryLevel = masteryLevel
        self.reviewCount = reviewCount
        self.updatedAt = updatedAt
        self.reviewHistory = reviewHistory
    }
}
```

---

### Task 4: 改造 ReviewEngine 适配四级间隔

**Files:**
- Modify: `chinese-poetry/Services/ReviewEngine.swift`

**Step 1: 更新间隔逻辑**

```swift
import Foundation

struct ReviewEngine {
    static func intervals(for level: MasteryLevel) -> [Int] {
        switch level {
        case .mastered:  [2, 4, 7, 15, 30]
        case .reviewing: [1, 2, 4, 7, 15]
        case .learning:  [1, 1, 2, 4, 7]
        case .new:       [1, 1, 2, 4, 7]
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

---

### Task 5: 新增 APIClient 网络层

**Files:**
- Create: `chinese-poetry/Services/APIClient.swift`

**Step 1: 创建 APIClient**

```swift
import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(String, Int)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "登录已过期，请重新登录"
        case .serverError(let msg, _): return msg
        case .invalidResponse: return "网络响应异常"
        case .networkError(let msg): return "网络错误：\(msg)"
        }
    }
}

struct ErrorResponse: Decodable {
    let error: String
}

class APIClient {
    static let shared = APIClient()

    private var _token: String?
    var token: String? {
        get { _token }
        set {
            _token = newValue
            if let token = newValue {
                KeychainHelper.save(token: token)
            } else {
                KeychainHelper.deleteToken()
            }
        }
    }

    var baseURL: String {
        UserDefaults.standard.string(forKey: "serverBaseURL") ?? ""
    }

    private init() {
        _token = KeychainHelper.loadToken()
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard !baseURL.isEmpty else {
            throw APIError.networkError("服务器地址未配置")
        }

        var urlString = "\(baseURL)/api/v1\(path)"
        if !urlString.hasPrefix("http") {
            urlString = "http://\(urlString)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.networkError("无效的 URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if let token = _token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 {
            token = nil
            throw APIError.unauthorized
        }

        if !(200...299).contains(http.statusCode) {
            let err = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(err?.error ?? "未知错误", http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
```

**Step 2: 新增 KeychainHelper**

创建 `chinese-poetry/Services/KeychainHelper.swift`：

```swift
import Foundation
import Security

struct KeychainHelper {
    private static let service = "com.poetry.app"
    private static let account = "auth_token"

    static func save(token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

---

### Task 6: 新增 AuthService 认证服务

**Files:**
- Create: `chinese-poetry/Services/AuthService.swift`

**Step 1: 创建 AuthService 和 API 请求/响应模型**

```swift
import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RegisterRequest: Encodable {
    let username: String
    let password: String
}

struct AuthResponse: Decodable {
    let token: String
    let user: UserInfo
}

struct UserInfo: Decodable {
    let id: UInt64
    let username: String
    let role: String
}

struct AuthService {
    static func register(username: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await APIClient.shared.request(
            "/auth/register",
            method: "POST",
            body: RegisterRequest(username: username, password: password)
        )
        APIClient.shared.token = response.token
        return response
    }

    static func login(username: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await APIClient.shared.request(
            "/auth/login",
            method: "POST",
            body: LoginRequest(username: username, password: password)
        )
        APIClient.shared.token = response.token
        return response
    }

    static func logout() {
        APIClient.shared.token = nil
    }

    static var isLoggedIn: Bool {
        APIClient.shared.token != nil
    }
}
```

---

### Task 7: 新增 AuthView 登录注册 UI

**Files:**
- Create: `chinese-poetry/Views/AuthView.swift`

**Step 1: 创建登录注册页面**

包含用户名/密码输入、登录/注册切换、错误提示、服务器配置入口：

```swift
import SwiftUI

struct AuthView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isRegisterMode = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @AppStorage("serverBaseURL") private var serverBaseURL = ""
    @State private var showServerConfig = false
    @State private var isLoggedIn = false

    var body: some View {
        if isLoggedIn {
            ContentView()
        } else {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("古诗词背诵")
                            .font(.title.bold())
                        Text(isRegisterMode ? "创建新账号" : "登录你的账号")
                            .foregroundStyle(.secondary)

                        VStack(spacing: 12) {
                            TextField("用户名", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            SecureField("密码", text: $password)
                                .textContentType(.password)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isRegisterMode ? "注册" : "登录")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(formValid ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(!formValid || isLoading)

                        Button(isRegisterMode ? "已有账号？去登录" : "没有账号？去注册") {
                            isRegisterMode.toggle()
                            errorMessage = nil
                        }
                        .font(.subheadline)

                        Divider()

                        Button {
                            showServerConfig = true
                        } label: {
                            Label("服务器设置", systemImage: "gearshape")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                }
                .navigationTitle(isRegisterMode ? "注册" : "登录")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showServerConfig) {
                    ServerConfigView()
                }
            }
        }
    }

    private var formValid: Bool {
        username.count >= 3 && username.count <= 64 && password.count >= 6
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        do {
            if isRegisterMode {
                _ = try await AuthService.register(username: username, password: password)
            } else {
                _ = try await AuthService.login(username: username, password: password)
            }
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ServerConfigView: View {
    @AppStorage("serverBaseURL") private var serverBaseURL = ""
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("服务器地址", text: $draft, prompt: Text("例如：http://192.168.1.100:3000"))
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("输入后端服务器的完整地址，包含端口号")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    serverBaseURL = draft
                    dismiss()
                } label: {
                    Text("保存")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(draft.isEmpty ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(draft.isEmpty)
            }
            .padding()
            .navigationTitle("服务器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { draft = serverBaseURL }
        }
    }
}

#Preview {
    AuthView()
}
```

---

### Task 8: 改造 PoemLoader 支持 API 加载

**Files:**
- Modify: `chinese-poetry/Services/PoemLoader.swift`

**Step 1: 添加 API 数据模型和网络加载方法**

```swift
import Foundation

struct PoemSummary: Codable {
    let total: Int
    let categories: [String: Int]
}

struct PoemListResponse: Decodable {
    let poems: [Poem]
    let total: Int
    let page: Int
    let per_page: Int
}

struct PoemLoader {
    nonisolated static func loadPoems() throws -> [Poem] {
        guard let url = Bundle.main.url(forResource: "poems", withExtension: "json") else {
            throw PoemError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Poem].self, from: data)
    }

    static func loadSummary() -> PoemSummary {
        guard let url = Bundle.main.url(forResource: "poem_summary", withExtension: "json") else {
            return PoemSummary(total: 0, categories: [:])
        }
        guard let data = try? Data(contentsOf: url),
              let summary = try? JSONDecoder().decode(PoemSummary.self, from: data) else {
            return PoemSummary(total: 0, categories: [:])
        }
        return summary
    }

    nonisolated static func loadCategoryPoems(category: String) async throws -> [Poem] {
        let poems = try await Task.detached { try loadPoems() }.value
        return filter(poems: poems, byCategory: category)
    }

    nonisolated static func filter(poems: [Poem], byGrade grade: Int) -> [Poem] {
        poems.filter { $0.grade == grade }
    }

    nonisolated static func filter(poems: [Poem], byCategory category: String) -> [Poem] {
        poems.filter { $0.category == category }
    }

    nonisolated static func search(poems: [Poem], query: String) -> [Poem] {
        guard !query.isEmpty else { return poems }
        return poems.filter {
            $0.title.contains(query) ||
            $0.poetName.contains(query) ||
            $0.paragraphs.contains { $0.contains(query) }
        }
    }

    // MARK: - API 加载

    static func fetchPoems(keyword: String? = nil,
                           dynasty: String? = nil,
                           category: String? = nil,
                           grade: Int? = nil,
                           page: Int = 1,
                           perPage: Int = 100) async throws -> PoemListResponse {
        var params: [String] = ["page=\(page)", "per_page=\(perPage)"]
        if let keyword { params.append("keyword=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)") }
        if let dynasty { params.append("dynasty=\(dynasty.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dynasty)") }
        if let category { params.append("category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)") }
        if let grade { params.append("grade=\(grade)") }
        let path = "/poems?\(params.joined(separator: "&"))"
        return try await APIClient.shared.request(path)
    }

    static func fetchAllPoems() async throws -> [Poem] {
        var allPoems: [Poem] = []
        var page = 1
        let perPage = 100
        while true {
            let response: PoemListResponse = try await fetchPoems(page: page, perPage: perPage)
            allPoems.append(contentsOf: response.poems)
            if page * perPage >= response.total {
                break
            }
            page += 1
        }
        return allPoems
    }
}

enum PoemError: Error {
    case fileNotFound
}
```

---

### Task 9: 新增 SyncService 进度同步服务

**Files:**
- Create: `chinese-poetry/Services/SyncService.swift`

**Step 1: 创建同步 API 模型和 SyncService**

```swift
import Foundation
import SwiftData

// MARK: - API 模型

struct RemoteLearningRecord: Decodable {
    let id: UInt64
    let poem_id: UInt64
    let poem_title: String
    let poet_name: String
    let mastery_level: String
    let review_count: UInt32
    let next_review_date: String?
    let created_at: String
    let updated_at: String
}

struct SyncRequest: Encodable {
    let records: [SyncRecord]
}

struct SyncRecord: Encodable {
    let poem_id: UInt64
    let mastery_level: String
    let review_count: UInt32
    let next_review_date: String?
    let updated_at: String
}

struct SyncResponse: Decodable {
    let synced: UInt32
    let skipped: UInt32
}

// MARK: - SyncService

struct SyncService {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func formatDate(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        return isoFormatter.date(from: string)
    }

    // MARK: - 下拉（从云端拉取全量记录）

    static func fetchAllProgress() async throws -> [RemoteLearningRecord] {
        try await APIClient.shared.request("/progress")
    }

    static func fetchDueReviews() async throws -> [RemoteLearningRecord] {
        try await APIClient.shared.request("/progress/due")
    }

    // MARK: - 上传（同步本地记录到云端）

    static func syncRecords(_ records: [LearningRecord]) async throws -> SyncResponse {
        let syncRecords = records.map { record in
            SyncRecord(
                poem_id: record.poemId,
                mastery_level: record.masteryLevel.rawValue,
                review_count: UInt32(record.reviewCount),
                next_review_date: record.nextReviewDate > Date.distantPast ? formatDate(record.nextReviewDate) : nil,
                updated_at: formatDate(record.updatedAt)
            )
        }
        let body = SyncRequest(records: syncRecords)
        return try await APIClient.shared.request("/progress", method: "POST", body: body)
    }

    // MARK: - 合并（云端记录覆盖本地）

    static func mergeRemoteRecords(_ remoteRecords: [RemoteLearningRecord], into context: ModelContext) throws {
        let descriptor = FetchDescriptor<LearningRecord>()
        let localRecords = try context.fetch(descriptor)
        var localByPoemId: [UInt64: LearningRecord] = [:]
        for r in localRecords { localByPoemId[r.poemId] = r }

        for remote in remoteRecords {
            let remoteUpdatedAt = parseDate(remote.updated_at) ?? Date.distantPast

            if let local = localByPoemId[remote.poem_id] {
                if remoteUpdatedAt > local.updatedAt {
                    applyRemote(remote, to: local)
                }
            } else {
                let record = createFromRemote(remote)
                context.insert(record)
            }
        }

        try context.save()
    }

    private static func applyRemote(_ remote: RemoteLearningRecord, to local: LearningRecord) {
        local.remoteId = remote.id
        local.masteryLevel = MasteryLevel(rawValue: remote.mastery_level) ?? .learning
        local.reviewCount = Int(remote.review_count)
        local.nextReviewDate = parseDate(remote.next_review_date) ?? Date()
        local.updatedAt = parseDate(remote.updated_at) ?? Date()
    }

    private static func createFromRemote(_ remote: RemoteLearningRecord) -> LearningRecord {
        LearningRecord(
            remoteId: remote.id,
            poemId: remote.poem_id,
            poemTitle: remote.poem_title,
            poetName: remote.poet_name,
            learnedDate: parseDate(remote.created_at) ?? Date(),
            nextReviewDate: parseDate(remote.next_review_date) ?? Date(),
            masteryLevel: MasteryLevel(rawValue: remote.mastery_level) ?? .learning,
            reviewCount: Int(remote.review_count),
            updatedAt: parseDate(remote.updated_at) ?? Date()
        )
    }

    // MARK: - 离线数据上传

    static func uploadLocalRecords(_ records: [LearningRecord]) async throws -> SyncResponse {
        try await syncRecords(records)
    }
}
```

---

### Task 10: 适配 HomeView

**Files:**
- Modify: `chinese-poetry/Views/HomeView.swift`

**Step 1: 修改字段引用**

将 `poem.author` 改为 `poem.poetName`。HomeView 只用了 `PoemLoader.loadPoems().count` 获取总数，不需要改动字段引用，但需要确保加载兼容。

检查 HomeView 中对 Poem 的引用：HomeView 本身不直接使用 poem 字段，只是通过 `PoemLoader.loadPoems().count` 获取总数，以及传递给 `LearnView()` 等子页面。所以 HomeView 本身无需修改。

---

### Task 11: 适配 LearnView

**Files:**
- Modify: `chinese-poetry/Views/LearnView.swift`

**Step 1: 修改字段引用和记录创建**

- 将 `poem.author` → `poem.poetName`
- `records.map(\.poemId)` 现在类型是 `Set<UInt64>`，与 `poem.id: UInt64` 匹配
- `addRecord` 中创建 `LearningRecord` 需要传递新字段：

```swift
private func addRecord(poem: Poem, level: MasteryLevel) {
    let engine = ReviewEngine()
    let nextDate = engine.calculateNextReviewDate(
        reviewCount: 0, level: level, from: Date()
    )
    let record = LearningRecord(
        poemId: poem.id,
        poemTitle: poem.title,
        poetName: poem.poetName,
        nextReviewDate: nextDate,
        masteryLevel: level,
        updatedAt: Date()
    )
    modelContext.insert(record)
    Task { try? await SyncService.syncRecords([record]) }
}
```

完整修改见文件。关键点：所有 `poem.author` → `poem.poetName`，`LearningRecord` 初始化增加 `poemTitle`, `poetName`, `updatedAt` 参数。

---

### Task 12: 适配 ReviewView

**Files:**
- Modify: `chinese-poetry/Views/ReviewView.swift`

**Step 1: 修改字段引用和排序逻辑**

- 将 `poem.author` → `poem.poetName`
- `poemMap` 的 key 类型从 `String` 改为 `UInt64`：
  ```swift
  private var poemMap: [UInt64: Poem] {
      Dictionary(uniqueKeysWithValues: poems.map { ($0.id, $0) })
  }
  ```
- `ForEach` 的 `id` 从 `\.element.poemId` 改为保持 `\.element.poemId`（已经是 `UInt64` 且实现了 Hashable）
- `masteryText`, `masteryIcon`, `masteryColor` 适配四级：
  ```swift
  private func masteryText(_ level: MasteryLevel) -> String {
      switch level {
      case .new: "未学"
      case .learning: "学习中"
      case .reviewing: "复习中"
      case .mastered: "已掌握"
      }
  }
  
  private func masteryIcon(_ level: MasteryLevel) -> String {
      switch level {
      case .new: "circle"
      case .learning: "star"
      case .reviewing: "star.leadinghalf.filled"
      case .mastered: "star.fill"
      }
  }
  
  private func masteryColor(_ level: MasteryLevel) -> Color {
      switch level {
      case .new: .gray
      case .learning: .red
      case .reviewing: .orange
      case .mastered: .green
      }
  }
  
  private func masteryOrder(_ level: MasteryLevel) -> Int {
      switch level {
      case .new: 0
      case .learning: 1
      case .reviewing: 2
      case .mastered: 3
      }
  }
  ```
- `updateRecord` 末尾增加更新 `updatedAt` 和触发同步：
  ```swift
  record.updatedAt = Date()
  Task { try? await SyncService.syncRecords([record]) }
  ```

---

### Task 13: 适配 PoemDetailView

**Files:**
- Modify: `chinese-poetry/Views/PoemDetailView.swift`

**Step 1: 修改字段引用**

- `poem.author` → `poem.poetName`
- `records.contains { $0.poemId == poem.id }` 的 `poemId` 现在是 `UInt64`，与 `poem.id` 类型匹配
- `addToLearning` 中创建 `LearningRecord` 增加 `poemTitle`, `poetName`, `updatedAt`：
  ```swift
  let record = LearningRecord(
      poemId: poem.id,
      poemTitle: poem.title,
      poetName: poem.poetName,
      nextReviewDate: nextDate,
      masteryLevel: .learning,
      updatedAt: Date()
  )
  ```
- `addToLearning` 末尾触发同步：`Task { try? await SyncService.syncRecords([record]) }`
- Preview 中的 `Poem(id:)` 构造改为 `Poem(id: 1, ...)` 并使用新字段名

---

### Task 14: 适配 PoemLibraryView

**Files:**
- Modify: `chinese-poetry/Views/PoemLibraryView.swift`

**Step 1: 修改字段引用和筛选逻辑**

- `poem.author` → `poem.poetName`
- `learnedIds` 类型从 `Set<String>` 改为 `Set<UInt64>`：
  ```swift
  private var learnedIds: Set<UInt64> { Set(records.map(\.poemId)) }
  ```
- 排序从 `Int($0.id)` 改为直接 `$0.id`（`UInt64` 已实现 Comparable）
- `addToLearning` 中 `LearningRecord` 初始化增加 `poemTitle`, `poetName`, `updatedAt`
- 触发同步

---

### Task 15: 适配 QuizView, RecitationView

**Files:**
- Modify: `chinese-poetry/Views/QuizView.swift`
- Modify: `chinese-poetry/Views/RecitationView.swift`

**Step 1: QuizView**

- `poemMap` key 类型 `String` → `UInt64`
- `poem.author` → `poem.poetName`

**Step 2: RecitationView**

- `poem.author` → `poem.poetName`
- Preview 构造适配新字段名

---

### Task 16: 改造 chinese_poetryApp 入口

**Files:**
- Modify: `chinese-poetry/chinese_poetryApp.swift`

**Step 1: 根据登录状态显示不同页面**

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

    @AppStorage("serverBaseURL") private var serverBaseURL = ""

    var body: some Scene {
        WindowGroup {
            if !serverBaseURL.isEmpty && AuthService.isLoggedIn {
                ContentView()
                    .task {
                        await initialSync()
                    }
            } else if !serverBaseURL.isEmpty && !AuthService.isLoggedIn {
                AuthView()
            } else {
                ContentView()
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func initialSync() async {
        guard AuthService.isLoggedIn else { return }
        do {
            let remoteRecords = try await SyncService.fetchAllProgress()
            try SyncService.mergeRemoteRecords(remoteRecords, into: sharedModelContainer.mainContext)
        } catch {
            // 同步失败不阻塞 UI
        }
    }
}
```

---

### Task 17: 适配 BackupService + BackupDocument

**Files:**
- Modify: `chinese-poetry/Services/BackupService.swift`
- Modify: `chinese-poetry/Models/BackupDocument.swift`

**Step 1: BackupDocument 更新字段**

- `BackupRecord.poemId` 从 `String` 改为 `UInt64`
- `BackupData.version` 改为 2
- 增加 `BackupSettings.serverBaseURL: String?`

**Step 2: BackupService 更新**

- `BackupService.currentVersion` 改为 2
- `exportData` / `importData` 适配 `poemId: UInt64`
- `applySettings` 增加 `serverBaseURL` 恢复
- 导入时检测 version，v1 数据做三级→四级映射

```swift
// BackupService 关键修改
private static let currentVersion = 2

// exportData 中适配新字段
let backupRecords = records.map { record in
    BackupRecord(
        poemId: record.poemId,
        // ... 其余字段
    )
}

// importData 中检测版本做映射
if backup.version == 1 {
    // v1 的 poemId 是 String，需要兼容处理
}
```

---

### Task 18: 编译验证 + 修复编译错误

**Step 1: 构建**

```bash
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -30
```

**Step 2: 修复所有编译错误**

逐一检查编译错误，修复剩余的字段名引用和类型不匹配问题。

---

### Task 19: 运行测试

```bash
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -30
```

---

### Task 20: 适配 SettingsView 增加服务器配置和登录入口

**Files:**
- Modify: `chinese-poetry/Views/SettingsView.swift`

**Step 1: 增加"服务器地址"和"账号"设置区块**

在 SettingsView 中新增设置区块，包含服务器地址输入、登录/登出按钮：

增加 `@AppStorage("serverBaseURL")` 和服务器配置 sheet、登出确认 alert。
