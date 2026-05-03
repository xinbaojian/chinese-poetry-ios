# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

儿童古诗词背诵 iOS App — 帮助小学生通过艾宾浩斯记忆曲线背诵古诗词。纯本地 App，无后端、无登录、无广告。

MVP 核心功能：诗词浏览背诵、艾宾浩斯记忆曲线复习、iOS 本地推送提醒、自动筛选待复习诗词。

详细需求文档：`docs/儿童古诗词背诵 App iOS 版第一版 MVP 最小功能清单.md`

古诗词原始数据位于 `/Users/xinbaojian/workspace/front/chinese-poetry`。

## Build & Test Commands

```bash
# 构建
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' build

# 运行单元测试
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' test

# 运行单个测试
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:chinese-poetryTests/chinese_poetryTests/testExample test
```

也可以直接用 `xcodebuild test` 简写（在项目根目录下）。

## Architecture

- **SwiftUI + SwiftData** — 声明式 UI + 本地持久化
- **Xcode Project**（非 SPM 包），Swift 5.0，多平台（iOS/macOS/visionOS）
- **Swift Testing** 框架（`import Testing`，使用 `@Test` + `#expect`），非 XCTest
- 数据层全部本地，使用 SwiftData `@Model` + `ModelContainer`

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
