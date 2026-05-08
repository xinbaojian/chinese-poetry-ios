# 儿童古诗词背诵

帮助小学生通过艾宾浩斯记忆曲线背诵古诗词的 iOS App。纯本地应用，无需登录、无广告、无内购。

## 功能

- **诗词库** — 内置部编版小学 1-6 年级必背古诗词，支持按年级筛选和搜索
- **学习计划** — 将诗词加入学习计划，支持遮挡自测、拼音标注，左右滑动切换诗词
- **智能复习** — 基于艾宾浩斯记忆曲线自动安排复习，根据掌握程度调整间隔
- **语音背诵** — iOS 原生语音识别，背诵后自动对比原文并标注差异
- **每日提醒** — iOS 本地推送通知，自定义提醒时间
- **随机测验** — 从已学诗词中随机抽取进行测验
- **数据备份** — 支持导出/导入学习进度（JSON 格式）

## 技术栈

- **SwiftUI + SwiftData** — 声明式 UI + 本地持久化
- **Swift 5.0**，最低部署目标 iOS 15
- **Xcode Project**（非 SPM），支持 iOS / macOS / visionOS
- **Swift Testing** 框架（`import Testing`）

## 项目结构

```
chinese-poetry/
├── chinese-poetry/
│   ├── Models/
│   │   ├── Poem.swift              # 诗词数据模型
│   │   ├── LearningRecord.swift    # 学习记录（SwiftData）
│   │   ├── MasteryLevel.swift      # 掌握程度枚举
│   │   └── BackupDocument.swift    # 备份文档模型
│   ├── Views/
│   │   ├── HomeView.swift          # 首页（任务概览 + 功能入口）
│   │   ├── PoemLibraryView.swift   # 诗词库（筛选、搜索）
│   │   ├── PoemDetailView.swift    # 诗词详情（拼音、释义）
│   │   ├── LearnView.swift         # 学习页（遮挡自测、滑动切换）
│   │   ├── ReviewView.swift        # 复习页（滑动切换）
│   │   ├── RecitationView.swift    # 语音背诵页（识别、对比结果）
│   │   ├── QuizView.swift          # 随机测验
│   │   ├── SettingsView.swift      # 设置（备份、提醒）
│   │   └── PinyinText.swift        # 拼音标注组件
│   ├── Services/
│   │   ├── PoemLoader.swift        # 诗词数据加载
│   │   ├── ReviewEngine.swift      # 艾宾浩斯复习引擎
│   │   ├── PinyinHelper.swift      # 拼音转换
│   │   ├── RecitationChecker.swift # 背诵对比算法（拼音编辑距离）
│   │   ├── SpeechRecognizer.swift  # 语音识别（SFSpeechRecognizer）
│   │   ├── NotificationManager.swift # 推送通知
│   │   └── BackupService.swift     # 备份导入导出
│   ├── ContentView.swift           # 主视图
│   └── chinese_poetryApp.swift     # App 入口
├── chinese-poetryTests/            # 单元测试
├── chinese-poetryUITests/          # UI 测试
├── docs/                           # 产品文档
└── Resources/
    └── poems.json                  # 诗词数据库
```

## 构建与运行

```bash
# 构建
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# 运行单元测试
xcodebuild -project chinese-poetry.xcodeproj -scheme chinese-poetry \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

或直接用 Xcode 打开 `chinese-poetry.xcodeproj`，选择模拟器运行。

## 艾宾浩斯复习间隔

| 掌握程度 | 复习间隔（天） |
|----------|---------------|
| 熟练 | 1 → 2 → 4 → 7 → 15 |
| 一般 | 1 → 1 → 2 → 4 → 7 |
| 不熟练 | 1 → 1 → 1 → 2 → 4 |

## 文档

- [MVP 功能清单](docs/儿童古诗词背诵%20App%20iOS%20版第一版%20MVP%20最小功能清单.md)
- [语音背诵识别功能需求与开发文档](docs/语音背诵识别功能需求与开发文档.md)
