import Foundation

struct RecitationChecker {
    enum CharStatus: Sendable {
        case correct
        case wrong
        case missing
        case extra
    }

    struct AlignedChar: Sendable {
        let original: String?
        let recognized: String?
        let status: CharStatus
    }

    struct Result: Sendable {
        let alignedChars: [AlignedChar]
        let accuracy: Double
        let correctCount: Int
        let wrongCount: Int
        let missingCount: Int
        let extraCount: Int
    }

    static func check(original: String, recognized: String, headerToSkip: String = "") -> Result {
        let origChars = filterChinese(original)
        var recChars = filterChinese(recognized)

        // 剥离孩子背诵时先念的标题/朝代/作者（按拼音顺序匹配，遇到不匹配则停止）
        if !headerToSkip.isEmpty {
            let headerChars = filterChinese(headerToSkip)
            let headerPinyin = headerChars.map { PinyinHelper.stripTone(PinyinHelper.pinyin(for: $0) ?? $0) }
            let recPinyin = recChars.map { PinyinHelper.stripTone(PinyinHelper.pinyin(for: $0) ?? $0) }

            var headerIdx = 0
            var recIdx = 0
            while headerIdx < headerPinyin.count && recIdx < recPinyin.count {
                if headerPinyin[headerIdx] == recPinyin[recIdx] {
                    headerIdx += 1
                    recIdx += 1
                } else {
                    break
                }
            }
            // 只有 header 全部匹配时才剥离，避免标题与正文开头拼音重叠导致误剥
            if headerIdx == headerPinyin.count && recIdx > 0 {
                recChars = Array(recChars.dropFirst(recIdx))
            }
        }

        let origPinyin = origChars.map { PinyinHelper.stripTone(PinyinHelper.pinyin(for: $0) ?? $0) }
        let recPinyin = recChars.map { PinyinHelper.stripTone(PinyinHelper.pinyin(for: $0) ?? $0) }

        let ops = align(origPinyin, recPinyin)

        var alignedChars: [AlignedChar] = []
        var correctCount = 0, wrongCount = 0, missingCount = 0, extraCount = 0

        for op in ops {
            switch op {
            case .match(let oi, let ri):
                alignedChars.append(AlignedChar(original: origChars[oi], recognized: recChars[ri], status: .correct))
                correctCount += 1
            case .substitute(let oi, let ri):
                alignedChars.append(AlignedChar(original: origChars[oi], recognized: recChars[ri], status: .wrong))
                wrongCount += 1
            case .delete(let oi):
                alignedChars.append(AlignedChar(original: origChars[oi], recognized: nil, status: .missing))
                missingCount += 1
            case .insert(let ri):
                alignedChars.append(AlignedChar(original: nil, recognized: recChars[ri], status: .extra))
                extraCount += 1
            }
        }

        let total = correctCount + wrongCount + missingCount
        let accuracy = total > 0 ? Double(correctCount) / Double(total) : 0

        return Result(
            alignedChars: alignedChars,
            accuracy: accuracy,
            correctCount: correctCount,
            wrongCount: wrongCount,
            missingCount: missingCount,
            extraCount: extraCount
        )
    }

    // MARK: - Private

    private enum Op {
        case match(Int, Int)
        case substitute(Int, Int)
        case delete(Int)
        case insert(Int)
    }

    private static func filterChinese(_ text: String) -> [String] {
        text.unicodeScalars.filter {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
            ($0.value >= 0x3400 && $0.value <= 0x4DBF)
        }.map { String($0) }
    }

    private static func align(_ original: [String], _ recognized: [String]) -> [Op] {
        let n = original.count
        let m = recognized.count

        if n == 0 && m == 0 { return [] }
        if n == 0 { return recognized.indices.map { .insert($0) } }
        if m == 0 { return original.indices.map { .delete($0) } }

        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                if original[i - 1] == recognized[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(
                        dp[i - 1][j] + 1,
                        dp[i][j - 1] + 1,
                        dp[i - 1][j - 1] + 1
                    )
                }
            }
        }

        var ops: [Op] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && original[i - 1] == recognized[j - 1] && dp[i][j] == dp[i - 1][j - 1] {
                ops.append(.match(i - 1, j - 1))
                i -= 1; j -= 1
            } else if i > 0 && dp[i][j] == dp[i - 1][j] + 1 {
                ops.append(.delete(i - 1))
                i -= 1
            } else if j > 0 && dp[i][j] == dp[i][j - 1] + 1 {
                ops.append(.insert(j - 1))
                j -= 1
            } else {
                ops.append(.substitute(i - 1, j - 1))
                i -= 1; j -= 1
            }
        }

        return ops.reversed()
    }
}
