import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @AppStorage("dailyNewLimit") private var dailyNewLimit = 5
    @AppStorage("learnMode") private var learnMode = "sequential"
    @AppStorage("showPinyin") private var showPinyin = true
    @AppStorage("autoHideContent") private var autoHideContent = false
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 9
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("serverBaseURL") private var serverBaseURL = "https://poetry.xiuyuan.xin"
    @State private var showResetAlert = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showImportModeAlert = false
    @State private var pendingImportData: BackupData?
    @State private var exportDocument: BackupDocument?
    @State private var exportError: String?
    @State private var importError: String?
    @State private var importSuccess: String?
    @State private var showLogoutAlert = false

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
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection("学习设置") {
                        Stepper("每日新学上限：\(dailyNewLimit) 首", value: $dailyNewLimit, in: 1...999)
                        Divider()
                        Picker("学习模式", selection: $learnMode) {
                            Text("顺序学习").tag("sequential")
                            Text("随机抽取").tag("random")
                        }
                        .pickerStyle(.segmented)
                        Divider()
                        Toggle("显示拼音", isOn: $showPinyin)
                        Divider()
                        Toggle("进入复习自动遮挡", isOn: $autoHideContent)
                    }

                    settingsSection("复习提醒") {
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
                            Divider()
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

                    settingsSection("数据管理") {
                        HStack {
                            Text("已学习诗词")
                            Spacer()
                            Text("\(records.count) 首")
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        Button {
                            exportBackup()
                        } label: {
                            HStack {
                                Label("导出学习进度", systemImage: "square.and.arrow.up")
                                Spacer()
                                if records.isEmpty {
                                    Text("无数据")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(records.isEmpty)

                        Divider()

                        Button {
                            showImportPicker = true
                        } label: {
                            Label("导入学习进度", systemImage: "square.and.arrow.down")
                        }

                        Divider()

                        Button("清空所有学习进度", role: .destructive) {
                            showResetAlert = true
                        }
                    }

                    settingsSection("账号与同步") {
                        if AuthService.isLoggedIn {
                            HStack {
                                Text("同步状态")
                                Spacer()
                                if SyncManager.shared.isSyncing {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("同步中...")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                } else if SyncManager.shared.lastSyncError != nil {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("同步失败")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                } else if let date = SyncManager.shared.lastSyncDate {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(relativeTimeString(from: date))
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                } else {
                                    Text("尚未同步")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                }
                            }

                            Divider()

                            Button {
                                manualSync()
                            } label: {
                                HStack {
                                    Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                                    Spacer()
                                    if SyncManager.shared.isSyncing {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                            }
                            .disabled(SyncManager.shared.isSyncing)

                            Divider()
                        }

                        NavigationLink {
                            ServerConfigView()
                        } label: {
                            HStack {
                                Text("服务器地址")
                                Spacer()
                                Text(serverBaseURL.isEmpty ? "未配置" : serverBaseURL)
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                        }

                        Divider()

                        if AuthService.isLoggedIn {
                            NavigationLink {
                                ChangePasswordView()
                            } label: {
                                Label("修改密码", systemImage: "lock.rotation")
                            }

                            Divider()

                            Button("登出", role: .destructive) {
                                showLogoutAlert = true
                            }
                        } else if !serverBaseURL.isEmpty {
                            NavigationLink("去登录") {
                                AuthView()
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 60)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("设置")
            .alert("确认清空？", isPresented: $showResetAlert) {
                Button("清空", role: .destructive) { clearAllRecords() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清空后所有学习进度将丢失，此操作不可恢复。")
            }
            .alert("导入方式", isPresented: $showImportModeAlert) {
                Button("替换（覆盖现有数据）") {
                    performImport(mode: .replace)
                }
                Button("合并（保留较新的记录）") {
                    performImport(mode: .merge)
                }
                Button("取消", role: .cancel) {
                    pendingImportData = nil
                }
            } message: {
                if let backup = pendingImportData {
                    Text("检测到 \(backup.recordCount) 条记录，导出时间：\(backup.exportDate.formatted())")
                }
            }
            .alert("导出失败", isPresented: .constant(exportError != nil)) {
                Button("确定") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .alert("导入失败", isPresented: .constant(importError != nil)) {
                Button("确定") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .alert("导入成功", isPresented: .constant(importSuccess != nil)) {
                Button("确定") { importSuccess = nil }
            } message: {
                Text(importSuccess ?? "")
            }
            .alert("确认登出？", isPresented: $showLogoutAlert) {
                Button("登出", role: .destructive) {
                    Task {
                        await AuthService.logout()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("登出后本地学习记录会保留，下次登录时可重新同步。")
            }
            .fileExporter(
                isPresented: $showExportSheet,
                document: exportDocument,
                contentType: .json,
                defaultFilename: BackupService.exportFileName()
            ) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    exportError = error.localizedDescription
                }
                exportDocument = nil
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding()
            .background(.background, in: .rect(cornerRadius: 10))
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
            importError = "清空失败：\(error.localizedDescription)"
        }
    }

    private func exportBackup() {
        let settings = BackupService.buildSettings(
            dailyNewLimit: dailyNewLimit,
            learnMode: learnMode,
            showPinyin: showPinyin,
            autoHideContent: autoHideContent,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )

        do {
            let data = try BackupService.exportData(records: records, settings: settings)
            exportDocument = BackupDocument(data: data)
            showExportSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = "无法访问文件"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let backup = try BackupService.parseBackup(from: data)
                pendingImportData = backup
                showImportModeAlert = true
            } catch {
                importError = error.localizedDescription
            }

        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func performImport(mode: ImportMode) {
        guard let backup = pendingImportData else { return }
        do {
            try BackupService.importData(backup, mode: mode, context: modelContext)
            BackupService.applySettings(backup.settings)
            importSuccess = "成功导入 \(backup.recordCount) 条学习记录"
            let descriptor = FetchDescriptor<LearningRecord>()
            if let allRecords = try? modelContext.fetch(descriptor), !allRecords.isEmpty {
                Task { await SyncManager.shared.sync(records: allRecords) }
            }
        } catch {
            importError = error.localizedDescription
        }
        pendingImportData = nil
    }

    private func manualSync() {
        let descriptor = FetchDescriptor<LearningRecord>()
        guard let records = try? modelContext.fetch(descriptor) else { return }
        Task {
            await SyncManager.shared.sync(records: records)
            do {
                let remoteRecords = try await SyncService.fetchAllProgress()
                try SyncService.mergeRemoteRecords(remoteRecords, into: modelContext)
            } catch {
                SyncManager.shared.lastSyncError = error.localizedDescription
            }
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        switch seconds {
        case ..<0: return "刚刚"
        case 0..<60: return "\(seconds)秒前"
        case 60..<3600: return "\(seconds / 60)分钟前"
        case 3600..<86400: return "\(seconds / 3600)小时前"
        case 86400..<604800: return "\(seconds / 86400)天前"
        default: return date.formatted(.dateTime.year().month().day())
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
