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

# 运行单元测试
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 17' test
```

> **注意**：iPhone 17 Pro 模拟器存在磁盘问题，使用 iPhone 17。iPhone 16 不可用。

## Architecture

- **SwiftUI + SwiftData** — 声明式 UI + 本地持久化
- **Xcode Project**（非 SPM 包），Swift 5.0，多平台（iOS/macOS/visionOS）
- **Swift Testing** 框架（`import Testing`，使用 `@Test` + `#expect`），非 XCTest
- 数据层全部本地，使用 SwiftData `@Model` + `ModelContainer`
- **全局 MainActor**：`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，所有代码隐式 @MainActor
- **PBXFileSystemSynchronizedRootGroup**：源码目录下的文件由 Xcode 自动发现，无需手动配置 build phase

## Directory Layout

- `chinese-poetry/` — 主应用源码（SwiftUI Views、Models、App 入口）
- `chinese-poetryTests/` — 单元测试
- `chinese-poetryUITests/` — UI 测试
- `docs/` — 产品需求文档

## Key Technical Decisions

- **艾宾浩斯复习周期**：新学 → 第 1、2、4、7、15 天触发复习；不熟练则缩短间隔
- **iOS 本地推送通知**（`UserNotifications` framework）做复习提醒
- **拼音标注**：需在诗词详情页支持开关显示
- 诗词数据按年级（1-6）分类，来自部编版小学必背古诗词

## Conventions

### SourceKit 误报

SourceKit 经常报告 "Cannot find type X in scope" 错误，对于同一模块内其他文件定义的类型（如 `Poem`、`LearningRecord`、`SpeechRecognizer` 等）尤其常见。这些是 SourceKit 索引问题，**不是真正的编译错误**。以 `xcodebuild build` 的结果为准。

### UI 页面一致性

学习页面（LearnView）和复习页面（ReviewView）保持一致的 UI 模式：
- 按钮使用两行布局：遮挡自测 + 语音背诵一行（`SecondaryActionButton`），完成操作一行（`PrimaryActionButton`）
- 查看释义使用 `DisclosureGroup` + `translationExpanded` 状态，默认展开
- 诗词内容使用 `ScrollView` 包裹，适配长诗词
- 语音背诵通过 `.sheet` 弹出 `RecitationView`

### 持久化偏好

使用 `@AppStorage` 存储用户偏好，key 命名用驼峰式（如 `autoHideContent`、`dailyNewLimit`）。新增偏好时需同步更新：
1. `SettingsView` — 声明 `@AppStorage` + UI 开关
2. `BackupDocument.swift` — `BackupSettings` struct 增加字段
3. `BackupService.swift` — `buildSettings` 和 `applySettings` 方法同步

### 安全规范

- 备份导入是唯一接受外部不可信数据的入口，必须校验：记录数一致性、字段有效性、值域范围
- `applySettings` 中所有数值型设置使用 `clamp` 限制值域，字符串型设置使用白名单校验
- 破坏性操作（清空数据）的错误不得静默吞掉，必须提示用户
- `@Observable` 类的公开属性如不需外部修改，使用 `private(set)` 保护

### 语音识别

- 使用 `SFSpeechRecognizer`（zh-CN），`@Observable` 模式（非 ObservableObject）
- 权限请求：`SFSpeechRecognizer.requestAuthorization` + `AVAudioApplication.requestRecordPermission`（iOS 17+ API）
- 静默检测：每秒检查，5 秒无语音自动停止
- 错误通过 `onError` 回调通知 UI 层，识别回调中必须处理 error 参数

### 背诵对比算法

`RecitationChecker` 使用拼音级别 Levenshtein 编辑距离对齐：
1. 过滤只保留汉字（CJK Unified Ideographs）
2. 转换为去声调拼音
3. DP 编辑距离 + 回溯对齐（回溯顺序：match → delete → insert → substitute）
4. 结果按原诗 `displayLines` 结构分组展示（`groupByLines` 方法）

# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
