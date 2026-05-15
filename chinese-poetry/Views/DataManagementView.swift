import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [LearningRecord]
    @AppStorage("dailyNewLimit") private var dailyNewLimit = 5
    @AppStorage("learnMode") private var learnMode = "sequential"
    @AppStorage("showPinyin") private var showPinyin = true
    @AppStorage("autoHideContent") private var autoHideContent = false
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 9
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @State private var showResetAlert = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showImportModeAlert = false
    @State private var pendingImportData: BackupData?
    @State private var exportDocument: BackupDocument?
    @State private var exportError: String?
    @State private var importError: String?
    @State private var importSuccess: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsSection {
                    HStack {
                        Text("已学习诗词")
                        Spacer()
                        Text("\(records.count) 首")
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsSection {
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
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("数据管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认清空？", isPresented: $showResetAlert) {
            Button("清空", role: .destructive) { clearAllRecords() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清空后所有学习进度将丢失，此操作不可恢复。")
        }
        .alert("导入方式", isPresented: $showImportModeAlert) {
            Button("替换（覆盖现有数据）") { performImport(mode: .replace) }
            Button("合并（保留较新的记录）") { performImport(mode: .merge) }
            Button("取消", role: .cancel) { pendingImportData = nil }
        } message: {
            if let backup = pendingImportData {
                Text("检测到 \(backup.recordCount) 条记录，导出时间：\(backup.exportDate.formatted())")
            }
        }
        .alert("操作结果", isPresented: resultAlertBinding) {
            Button("确定") {
                exportError = nil
                importError = nil
                importSuccess = nil
            }
        } message: {
            Text(exportError ?? importError ?? importSuccess ?? "")
        }
        .fileExporter(
            isPresented: $showExportSheet,
            document: exportDocument,
            contentType: .json,
            defaultFilename: BackupService.exportFileName()
        ) { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in handleImportResult(result) }
    }

    private var resultAlertBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil || importError != nil || importSuccess != nil },
            set: { if !$0 { exportError = nil; importError = nil; importSuccess = nil } }
        )
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
            dailyNewLimit: dailyNewLimit, learnMode: learnMode,
            showPinyin: showPinyin, autoHideContent: autoHideContent,
            reminderEnabled: reminderEnabled, reminderHour: reminderHour,
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
                pendingImportData = try BackupService.parseBackup(from: data)
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
}
