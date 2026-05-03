import Foundation

struct PinyinHelper {
    struct AnnotatedChar: Identifiable {
        let id: Int
        let char: String
        let pinyin: String?
    }

    private static let corrections: [String: String] = [
        "还": "hái", "重": "chóng", "散": "sàn", "朝": "zhāo",
        "行": "xíng", "更": "gèng", "少": "shào", "长": "cháng",
        "看": "kàn", "觉": "jué", "落": "luò", "教": "jiào",
        "将": "jiāng", "相": "xiàng", "见": "jiàn", "度": "dù",
        "胜": "shèng", "乘": "chéng", "传": "chuán", "藏": "cáng",
        "当": "dāng", "弹": "tán", "强": "qiáng", "乐": "lè",
        "处": "chù", "似": "sì", "为": "wéi", "论": "lùn",
        "冠": "guān", "分": "fēn", "令": "lìng",
        "曾": "céng", "发": "fā", "间": "jiān", "奇": "qí",
        "号": "háo", "泊": "bó", "空": "kōng", "兴": "xìng",
    ]

    private static let punctuation = CharacterSet(charactersIn: "\u{FF0C}\u{3002}\u{FF1F}\u{FF01}\u{3001}\u{FF1B}\u{FF1A}\u{201C}\u{201D}\u{2018}\u{2019}\u{FF08}\u{FF09}\u{2014}\u{2026}\u{00B7}，。？！、；：\"\"''（）—…·")

    static func annotate(_ text: String) -> [AnnotatedChar] {
        var result: [AnnotatedChar] = []
        let nsString = text as NSString

        for i in 0..<nsString.length {
            let char = nsString.substring(with: NSRange(location: i, length: 1))
            let pinyin: String?

            if char.unicodeScalars.first.map({ punctuation.contains($0) }) == true
                || char.trimmingCharacters(in: .whitespaces).isEmpty {
                pinyin = nil
            } else if let corrected = corrections[char] {
                pinyin = corrected
            } else {
                pinyin = toPinyin(char)
            }

            result.append(AnnotatedChar(id: i, char: char, pinyin: pinyin))
        }

        return result
    }

    private static func toPinyin(_ char: String) -> String? {
        let mutable = NSMutableString(string: char)
        let transformed = CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        guard transformed else { return nil }
        let result = mutable as String
        return result == char ? nil : result.lowercased()
    }
}
