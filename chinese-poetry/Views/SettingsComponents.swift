import SwiftUI
import Foundation

struct SettingsSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: 10))
    }
}

extension Date {
    var relativeString: String {
        let seconds = Int(Date().timeIntervalSince(self))
        switch seconds {
        case ..<0: return "刚刚"
        case 0..<60: return "\(seconds)秒前"
        case 60..<3600: return "\(seconds / 60)分钟前"
        case 3600..<86400: return "\(seconds / 3600)小时前"
        case 86400..<604800: return "\(seconds / 86400)天前"
        default: return formatted(.dateTime.year().month().day())
        }
    }
}
