# 后端同步改造设计

## 目标

将 iOS 古诗词背诵 App 从纯本地改造为：从后端 API 读取诗词数据 + 同步学习进度到云端。

## 设计决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 掌握程度 | 改为后端四级（new/learning/reviewing/mastered） | 与后端完全一致，避免映射错误 |
| 离线策略 | 在线优先 + 离线缓存 | 保留离线可用性，同时享受云端同步 |
| 数据模型 | 完全对齐后端字段 | 减少转换层，降低维护成本 |
| 学习记录 | 改 SwiftData 字段 + 同步层 | 保留本地持久化优势，增加云端同步 |
| 后端地址 | 设置页可配置 | 适合多环境开发部署 |

## 架构

### 新增文件

| 文件 | 职责 |
|------|------|
| `Services/APIClient.swift` | HTTP 请求封装，Token 管理，错误处理 |
| `Services/AuthService.swift` | 注册/登录/登出，Keychain token 存取 |
| `Services/SyncService.swift` | 学习进度双向同步，离线队列 |
| `Views/AuthView.swift` | 登录/注册 UI |

### 改造文件

| 文件 | 改造内容 |
|------|----------|
| `Models/Poem.swift` | 字段对齐后端（id: UInt64, poet_name, content JSON 字符串等） |
| `Models/MasteryLevel.swift` | 改为 new/learning/reviewing/mastered 四级 |
| `Models/LearningRecord.swift` | 增加后端字段（poemTitle, poetName, updatedAt, remoteId） |
| `Services/PoemLoader.swift` | 改为从 API 加载，保留本地 JSON 兜底 |
| `Services/ReviewEngine.swift` | 适配四级掌握程度，重新设计间隔 |
| `Views/SettingsView.swift` | 增加"服务器地址"配置和"登录/登出"入口 |
| `Views/HomeView.swift` | 诗词总数从 API/cache 获取 |
| `Views/LearnView.swift` | 适配新 Poem 字段名，学习后触发同步 |
| `Views/ReviewView.swift` | 适配新字段名，复习后触发同步 |
| `Views/PoemLibraryView.swift` | 从 API 分页加载 |
| `Views/PoemDetailView.swift` | 适配新字段名 |
| `Views/QuizView.swift` | 适配新字段名 |
| `Services/BackupService.swift` | 适配新模型字段 |
| `Models/BackupDocument.swift` | 适配新模型字段 |
| `chinese_poetryApp.swift` | 根据登录状态显示 AuthView 或 ContentView |

### 数据流（改造后）

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   后端 API    │ ←→  │  APIClient   │ ←→  │ SyncService  │
│  (Rust/Actix) │     │ (URLSession) │     │ (进度同步)    │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                                                  ▼
                                          ┌──────────────┐
                                          │   SwiftData   │
                                          │LearningRecord│
                                          └──────┬───────┘
                                                  │ @Query
                                                  ▼
                                          ┌──────────────┐
                                          │  View 层      │
                                          │ Home/Learn/  │
                                          │ Review/etc.  │
                                          └──────────────┘
                                                  ↕
                                          ┌──────────────┐
                                          │  内存缓存      │
                                          │  [Poem]      │
                                          └──────────────┘
```

## 模型变更

### Poem（对齐后端 PoemItem）

```swift
struct Poem: Codable, Identifiable, Hashable {
    let id: UInt64           // 原为 String
    let title: String
    let poetName: String     // 原为 author
    let dynasty: String
    let category: String
    let grade: UInt8         // 原为 Int
    let content: String      // JSON 字符串，需二次解析
    let translation: String?

    var paragraphs: [String] { /* 从 content 解析 */ }
    var displayLines: [String] { /* 保留原有逻辑 */ }
}
```

### MasteryLevel（四级）

```swift
enum MasteryLevel: String, Codable {
    case new        // 未学
    case learning   // 学习中
    case reviewing  // 复习中
    case mastered   // 已掌握
}
```

### LearningRecord（SwiftData，增加后端字段）

```swift
@Model
final class LearningRecord {
    var remoteId: UInt64?       // 后端记录 ID
    var poemId: UInt64          // 原为 String
    var poemTitle: String       // 冗余字段，离线展示用
    var poetName: String        // 冗余字段
    var masteryLevel: MasteryLevel  // 四级
    var reviewCount: Int
    var nextReviewDate: Date
    var learnedDate: Date
    var updatedAt: Date         // 同步用时间戳
    var reviewHistory: [ReviewEntry]
}
```

### ReviewEngine（四级间隔）

按掌握程度分四档：
- `mastered`: [2, 4, 7, 15, 30] — 掌握了，间隔拉长
- `reviewing`: [1, 2, 4, 7, 15] — 复习中
- `learning`: [1, 1, 2, 4, 7]  — 学习中
- `new`: 不适用（首次学习后变为 learning/reviewing）

## 同步策略

### 首次登录（已有离线数据迁移）

1. 用户登录成功
2. 检测本地 SwiftData 是否有离线学习记录
3. 如果有，调用 `POST /progress` 批量上传（将旧三级映射为新的四级）
4. 然后调用 `GET /progress` 拉取云端全量记录，合并覆盖本地
5. 合并冲突规则：后端 `updated_at` 与本地 `updatedAt` 比较，保留更新的

### 日常同步

- **启动时**：`GET /progress` → 与本地合并
- **学习/复习后**：本地写入 SwiftData → 异步 `POST /progress` 单条同步
- **进入复习页**：可调用 `GET /progress/due` 获取最新待复习
- **离线**：所有操作写入本地，下次上线时批量同步

### 旧数据迁移映射

| 旧 MasteryLevel | 新 MasteryLevel |
|------------------|------------------|
| proficient       | mastered         |
| fair             | reviewing        |
| weak             | learning         |

旧记录没有 `updatedAt` 字段，迁移时设为 `learnedDate`。

## 认证流程

- App 启动检查 Keychain token
- 无 token → 显示 `AuthView`（登录/注册）
- 有 token → 显示 `ContentView`（主界面），后台静默验证
- 401 响应 → 清除 token，跳转 `AuthView`
- 设置页提供"登出"按钮

## 诗词加载策略

- 登录后从 `GET /poems` 分页加载全量诗词，缓存到内存
- 本地保留 `poems.json` 作为首次离线兜底
- 后续启动优先从 API 加载，失败时用缓存或本地 JSON
- `PoemLoader` 改为 `@Observable`，管理加载状态和网络请求

## 备份兼容性

- `BackupService` 适配新模型字段
- 导出格式增加 `version: 2` 标识
- 导入时检测版本，兼容 v1（旧三级）和 v2（新四级）数据
