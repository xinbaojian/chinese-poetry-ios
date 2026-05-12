# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

儿童古诗词背诵 iOS App — 帮助小学生通过艾宾浩斯记忆曲线背诵古诗词。纯本地 App，无后端、无登录、无广告。

MVP 核心功能：诗词浏览背诵、艾宾浩斯记忆曲线复习、iOS 本地推送提醒、自动筛选待复习诗词。

详细需求文档：`docs/儿童古诗词背诵 App iOS 版第一版 MVP 最小功能清单.md`

古诗词原始数据位于 `/Users/xinbaojian/workspace/front/chinese-poetry`。

## Build & Test Commands

```bash
# 构建（使用 iPhone 17 模拟器）
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 17' build

# 运行全部单元测试
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 17' test

# 运行单个测试文件（-only 参数使用 TestClassName/testMethodName 格式）
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 17' test -only:'chinese-poetryTests/ReviewEngineTests'
```

> **注意**：iPhone 17 Pro 模拟器存在磁盘问题，使用 iPhone 17。iPhone 16 不可用。

## Architecture

- **SwiftUI + SwiftData** — 声明式 UI + 本地持久化
- **Xcode Project**（非 SPM 包），Swift 5.0，多平台（iOS/macOS/visionOS）
- **Swift Testing** 框架（`import Testing`，使用 `@Test` + `#expect`），非 XCTest
- 数据层全部本地，使用 SwiftData `@Model` + `ModelContainer`
- **全局 MainActor**：`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，所有代码隐式 @MainActor
- **PBXFileSystemSynchronizedRootGroup**：源码目录下的文件由 Xcode 自动发现，无需手动配置 build phase

### 数据流架构

```
poems.json（静态数据） → PoemLoader → Poem struct（Codable，非持久化）
                                        ↓
LearningRecord（@Model SwiftData） ← View 层 @Query 响应式更新
                                        ↓
@AppStorage（UserDefaults） ← 用户偏好设置
```

- `Poem` 是纯值类型 struct，从 bundled JSON 加载，不经 SwiftData 持久化
- `LearningRecord` 是 SwiftData @Model，通过 poemId 与 Poem 关联
- `@Query` 在 HomeView/ReviewView 中自动刷新 UI，无需手动触发
- `@AppStorage` 存储偏好设置，key 用驼峰式命名

### 导航结构

- 入口：`ContentView` → 两个 Tab（首页 `HomeView` + 设置 `SettingsView`）
- 首页通过 `NavigationLink` 跳转到各功能页
- LearnView 和 ReviewView 内部使用 `TabView(page)` 实现左右滑动切换诗词

### 核心服务层

| 服务 | 职责 | 关键点 |
|------|------|--------|
| `ReviewEngine` | 艾宾浩斯复习间隔计算 | 间隔按掌握程度分三档：熟练[1,2,4,7,15]、一般[1,1,2,4,7]、不熟练[1,1,1,2,4] |
| `RecitationChecker` | 背诵对比（拼音级编辑距离） | 过滤汉字→去声调拼音→Wagner-Fischer DP→按 displayLines 分组展示 |
| `PinyinHelper` | 汉字转拼音 + 多音字修正 | 使用 CFStringTransform，内置 30+ 诗词常见多音字修正表 |
| `SpeechRecognizer` | 语音识别 | @Observable 模式，SFSpeechRecognizer(zh-CN)，5秒静默自动停止，contextualStrings 提升识别准确度 |
| `PoemLoader` | JSON 数据加载 | Task.detached 异步加载，支持按年级/分类筛选和全文搜索 |
| `BackupService` | 数据导入导出 | FileDocument 协议，版本化 JSON 格式，支持 replace/merge 两种导入模式，含完整数据校验 |
| `NotificationManager` | 本地推送通知 | UNUserNotificationCenter 封装，每日定时提醒 |

## Conventions

### SourceKit 误报

SourceKit 经常报告 "Cannot find type X in scope" 错误，对于同一模块内其他文件定义的类型（如 `Poem`、`LearningRecord`、`SpeechRecognizer` 等）尤其常见。这些是 SourceKit 索引问题，**不是真正的编译错误**。以 `xcodebuild build` 的结果为准。

### UI 页面一致性

LearnView 和 ReviewView 保持一致的 UI 模式：
- 按钮两行布局：遮挡自测 + 语音背诵（`SecondaryActionButton`），完成操作（`PrimaryActionButton`）
- 释义用 `DisclosureGroup` + `translationExpanded` 状态，默认展开
- 诗词内容用 `ScrollView` 包裹，适配长诗词
- 语音背诵通过 `.sheet` 弹出 `RecitationView`

### 持久化偏好同步

新增 `@AppStorage` 偏好时需同步更新三处：
1. `SettingsView` — 声明 `@AppStorage` + UI 开关
2. `BackupDocument.swift` — `BackupSettings` struct 增加字段
3. `BackupService.swift` — `buildSettings` 和 `applySettings` 方法同步

### 安全规范

- 备份导入是唯一外部数据入口，必须校验：记录数一致性、字段有效性、值域范围
- `applySettings` 中数值型设置使用 `clamp` 限制值域，字符串型设置使用白名单校验
- `@Observable` 类的公开属性如不需外部修改，使用 `private(set)` 保护

### 背诵对比算法（RecitationChecker）

1. 过滤只保留汉字（CJK Unified Ideographs U+4E00-U+9FFF, U+3400-U+4DBF）
2. 转换为去声调拼音（PinyinHelper.stripTone）
3. DP 编辑距离 + 回溯对齐（回溯优先级：match → delete → insert → substitute）
4. 结果按原诗 `displayLines` 结构分组展示（`groupByLines` 方法）
