import SwiftUI

struct PinyinText: View {
    let text: String
    let showPinyin: Bool
    let fontSize: CGFloat

    init(_ text: String, showPinyin: Bool, fontSize: CGFloat = 22) {
        self.text = text
        self.showPinyin = showPinyin
        self.fontSize = fontSize
    }

    var body: some View {
        if showPinyin {
            annotatedView
        } else {
            Text(text)
                .font(.system(size: fontSize))
        }
    }

    private var annotatedView: some View {
        let chars = PinyinHelper.annotate(text)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(chars) { item in
                VStack(spacing: 1) {
                    Text(item.pinyin ?? "")
                        .font(.system(size: fontSize * 0.55, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(item.char)
                        .font(.system(size: fontSize, weight: .medium))
                }
                .frame(width: item.pinyin != nil ? fontSize * 1.3 : fontSize * 0.5)
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        PinyinText("床前明月光，疑是地上霜。", showPinyin: true)
        PinyinText("床前明月光，疑是地上霜。", showPinyin: false)
    }
    .padding()
}
