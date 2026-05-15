import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var records: [LearningRecord]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    menuCard(
                        icon: "book.fill",
                        color: .blue,
                        title: "学习设置",
                        subtitle: "每日上限、学习模式、拼音显示"
                    ) {
                        LearningSettingsView()
                    }

                    menuCard(
                        icon: "bell.fill",
                        color: .orange,
                        title: "复习提醒",
                        subtitle: "每日推送提醒时间"
                    ) {
                        ReminderSettingsView()
                    }

                    menuCard(
                        icon: "externaldrive.fill",
                        color: .green,
                        title: "数据管理",
                        subtitle: "\(records.count) 首已学习 · 导入导出"
                    ) {
                        DataManagementView()
                    }

                    menuCard(
                        icon: "person.circle.fill",
                        color: .purple,
                        title: "账号与同步",
                        subtitle: AuthService.isLoggedIn ? "已登录" : "未登录"
                    ) {
                        AccountSyncView()
                    }
                }
                .padding()
                .padding(.bottom, 60)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("设置")
        }
    }

    private func menuCard<Destination: View>(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.background, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: LearningRecord.self, inMemory: true)
}
