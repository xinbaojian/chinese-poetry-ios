# 语音背诵识别功能 — 设计文档

## 概述

在复习页面新增「语音背诵」模式。孩子对着手机背诵诗词，系统通过 SFSpeechRecognizer 实时识别语音，转为文字后与原诗进行拼音级别对比，标注正确和错误位置，给出背诵评分。

## 设计决策

- **入口方式**：Sheet 弹窗，从 ReviewView 中诗词内容下方点击「语音背诵」按钮触发
- **结果展示**：逐字卡片样式，每个字独立显示拼音、汉字、对错标记

## 模块架构

```
Services/SpeechRecognizer.swift    — 语音识别管理器
Services/RecitationChecker.swift   — 拼音对比算法
Views/RecitationView.swift         — 背诵页面 UI（Sheet）
```

### SpeechRecognizer

- `SFSpeechRecognizer(locale: zh-CN)` + `AVAudioEngine` 实时流式识别
- `@Published recognizedText` / `isRecording` 驱动 SwiftUI UI
- `contextualStrings` 传入当前诗句提高识别准确率
- 5 秒静音自动停止
- `requestAuthorization()` 请求麦克风+语音识别权限

### RecitationChecker

核心算法流程：
1. 过滤原诗和识别文本中的标点，只保留汉字
2. 通过 PinyinHelper 将每个字转为拼音
3. 去掉声调（仅比较声母+韵母），容错小学生声调不准
4. 用 Levenshtein 编辑距离对齐两条拼音序列
5. 逐位置标记 CharStatus：correct / wrong / missing / extra
6. 计算正确率 = 匹配字数 / 原诗总字数

返回 `Result` 结构体，包含：
- `originalChars`：原诗汉字列表
- `statuses`：逐字状态数组
- `accuracy`：正确率 0.0~1.0
- 各状态计数

### RecitationView

以 `.sheet` 方式从 ReviewView 弹出，`presentationDetents([.large])` 全屏展示。

状态机：`ready → recording → result`

- **ready**：显示诗词标题作者 + 开始背诵按钮
- **recording**：麦克风动画 + 实时识别文字 + 停止按钮
- **result**：逐字卡片（拼音 + 汉字 + ✓/✗）+ 正确率百分比 + 重新背诵/完成按钮

## 集成点

- ReviewView 中诗词内容下方添加「语音背诵」按钮
- 复用 PinyinHelper 的拼音转换能力，新增 `stripTone()` 去声调方法
- 背诵完成后回到复习页选择掌握程度
- Info.plist 添加麦克风和语音识别权限描述

## 权限配置

Info.plist 新增：
- `NSMicrophoneUsageDescription`：需要使用麦克风录制您的背诵语音
- `NSSpeechRecognitionUsageDescription`：需要语音识别来对比您的背诵是否正确

## 边界情况

- 拒绝麦克风权限 → 弹窗提示跳转系统设置
- 语音识别不可用 → 按钮置灰提示
- 5 秒静音 → 自动停止并进入结果对比
- 完全为空 → 提示未检测到语音
- 完全无关内容 → 显示 0% 正确率
