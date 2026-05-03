//
//  SettingsView.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @AppStorage("dailyNewLimit") private var dailyNewLimit = 5
    @AppStorage("learnMode") private var learnMode = "sequential"
    @AppStorage("showPinyin") private var showPinyin = true
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 9
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @State private var showResetAlert = false

    private var reminderDate: Date {
        get {
            var components = DateComponents()
            components.hour = reminderHour
            components.minute = reminderMinute
            return Calendar.current.date(from: components) ?? Date()
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("学习设置") {
                    Stepper("每日新学上限：\(dailyNewLimit) 首", value: $dailyNewLimit, in: 1...999)

                    Picker("学习模式", selection: $learnMode) {
                        Text("顺序学习").tag("sequential")
                        Text("随机抽取").tag("random")
                    }
                    .pickerStyle(.segmented)

                    Toggle("显示拼音", isOn: $showPinyin)
                }

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
                        DatePicker("提醒时间", selection: Binding(
                            get: { reminderDate },
                            set: { newDate in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                reminderHour = components.hour ?? 9
                                reminderMinute = components.minute ?? 0
                                scheduleReminder()
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                }

                Section("数据管理") {
                    HStack {
                        Text("已学习诗词")
                        Spacer()
                        Text("\(records.count) 首")
                            .foregroundStyle(.secondary)
                    }
                    Button("清空所有学习进度", role: .destructive) {
                        showResetAlert = true
                    }
                }
            }
            .navigationTitle("设置")
            .alert("确认清空？", isPresented: $showResetAlert) {
                Button("清空", role: .destructive) { clearAllRecords() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清空后所有学习进度将丢失，此操作不可恢复。")
            }
        }
    }

    private func scheduleReminder() {
        if reminderEnabled {
            NotificationManager.scheduleDailyReminder(at: reminderHour, minute: reminderMinute)
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
