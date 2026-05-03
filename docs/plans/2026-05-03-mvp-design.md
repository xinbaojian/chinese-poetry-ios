# 儿童古诗词背诵 App MVP 设计

## 定位

帮助小学生通过艾宾浩斯记忆曲线背诵古诗词。纯本地 iOS App，无后端、无登录、无广告。

## 数据层

### 诗词数据集

手工整理部编版小学 1-6 年级必背古诗词（约 70-80 首），打包为 JSON Bundle 资源。

```swift
struct Poem: Codable, Identifiable {
    let id: String
    let title: String           // 静夜思
    let author: String          // 李白
    let dynasty: String         // 唐
    let grade: Int              // 1-6 年级
    let paragraphs: [String]    // ["床前明月光，疑是地上霜。", ...]
    let translation: String?    // 儿童版白话释义
}
```

数据来源：`/Users/xinbaojian/workspace/front/chinese-poetry`（chinese-poetry GitHub 仓库）。

### 学习记录（SwiftData）

```swift
enum MasteryLevel: String, Codable {
    case proficient    // 熟练
    case fair          // 一般
    case weak          // 不熟练
}

struct ReviewEntry: Codable {
    let date: Date
    let level: MasteryLevel
}

@Model class LearningRecord {
    var poemId: String
    var learnedDate: Date
    var nextReviewDate: Date
    var masteryLevel: MasteryLevel
    var reviewCount: Int
    var reviewHistory: [ReviewEntry]
}
```

## 艾宾浩斯复习引擎

简化周期：新学 → 第 1、2、4、7、15 天触发复习。

根据掌握程度调整间隔：

| 掌握程度 | 间隔序列（天） |
|---------|--------------|
| 熟练 | 1 → 2 → 4 → 7 → 15 |
| 一般 | 1 → 1 → 2 → 4 → 7 |
| 不熟练 | 1 → 1 → 1 → 2 → 4 |

每日自动筛选 `nextReviewDate <= 今天` 的诗词进入待复习列表。

## 模块架构（5 个 Tab）

| Tab | 功能 |
|-----|------|
| 首页 | 今日任务（新学 + 待复习数量）、已学统计、一键开始 |
| 诗词库 | 按年级筛选、搜索、诗词详情（原文/释义） |
| 学习 | 背诵流程：浏览跟读 → 遮挡自测 → 标记掌握程度 |
| 复习 | 待复习列表、进入复习流程 |
| 设置 | 每日新学限额（1-3 首）、提醒时间、进度管理 |

## 推送通知

- 使用 `UserNotifications` 本地通知
- App 启动时请求通知权限
- 每日检查待复习数量，调度次日提醒
- 支持自定义提醒时间、开关提醒

## UI 风格

卡通简约、大字体、低饱和度柔和配色，适合儿童。纯 SwiftUI 实现。

## 技术栈

- SwiftUI + SwiftData
- Swift 5.0，iOS 17+
- Swift Testing（`import Testing`）
- 无第三方依赖

## MVP 不包含

拼音标注、音频朗读、游戏闯关、积分系统、云端同步、社交分享。
