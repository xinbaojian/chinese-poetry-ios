import SwiftUI
import SwiftData

struct AccountSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("serverBaseURL") private var serverBaseURL = "https://poetry.xiuyuan.xin"
    @State private var showLogoutAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if AuthService.isLoggedIn {
                    SettingsSection {
                        HStack {
                            Text("同步状态")
                            Spacer()
                            syncStatusLabel
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
                    }
                }

                SettingsSection {
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
                }

                if AuthService.isLoggedIn {
                    SettingsSection {
                        NavigationLink {
                            ChangePasswordView()
                        } label: {
                            Label("修改密码", systemImage: "lock.rotation")
                        }

                        Divider()

                        Button("登出", role: .destructive) {
                            showLogoutAlert = true
                        }
                    }
                } else if !serverBaseURL.isEmpty {
                    SettingsSection {
                        NavigationLink {
                            AuthView()
                        } label: {
                            HStack {
                                Text("去登录")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("账号与同步")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认登出？", isPresented: $showLogoutAlert) {
            Button("登出", role: .destructive) {
                Task { await AuthService.logout() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("登出后本地学习记录会保留，下次登录时可重新同步。")
        }
    }

    @ViewBuilder
    private var syncStatusLabel: some View {
        if SyncManager.shared.isSyncing {
            ProgressView().controlSize(.small)
            Text("同步中...").foregroundStyle(.secondary).font(.subheadline)
        } else if SyncManager.shared.lastSyncError != nil {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("同步失败").foregroundStyle(.secondary).font(.subheadline)
        } else if let date = SyncManager.shared.lastSyncDate {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(date.relativeString).foregroundStyle(.secondary).font(.subheadline)
        } else {
            Text("尚未同步").foregroundStyle(.secondary).font(.subheadline)
        }
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
}
