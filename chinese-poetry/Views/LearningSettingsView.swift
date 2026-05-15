import SwiftUI

struct LearningSettingsView: View {
    @AppStorage("dailyNewLimit") private var dailyNewLimit = 5
    @AppStorage("learnMode") private var learnMode = "sequential"
    @AppStorage("showPinyin") private var showPinyin = true
    @AppStorage("autoHideContent") private var autoHideContent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsSection {
                    Stepper("每日新学上限：\(dailyNewLimit) 首", value: $dailyNewLimit, in: 1...999)
                    Divider()
                    HStack {
                        Text("学习模式")
                        Spacer()
                        Picker("", selection: $learnMode) {
                            Text("顺序").tag("sequential")
                            Text("随机").tag("random")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                }

                SettingsSection {
                    Toggle("显示拼音", isOn: $showPinyin)
                    Divider()
                    Toggle("进入复习自动遮挡", isOn: $autoHideContent)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("学习设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
