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
        return FlowLayout(spacing: 2) {
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
                .frame(width: item.pinyin != nil ? fontSize * 1.2 : fontSize * 0.5)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            PinyinText("床前明月光，疑是地上霜。", showPinyin: true)
            PinyinText("远上寒山石径斜，白云生处有人家。", showPinyin: true)
            PinyinText("桃花潭水深千尺，不及汪伦送我情。", showPinyin: true)
            PinyinText("床前明月光，疑是地上霜。", showPinyin: false)
        }
        .padding()
    }
}
