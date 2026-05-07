import Testing
import Foundation
@testable import chinese_poetry

struct RecitationCheckerTests {
    @Test("完美匹配返回100%正确率")
    func perfectMatch() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前明月光"
        )
        #expect(result.accuracy == 1.0)
        #expect(result.correctCount == 5)
        #expect(result.wrongCount == 0)
        #expect(result.missingCount == 0)
        #expect(result.extraCount == 0)
    }

    @Test("错字被标记为wrong")
    func wrongCharacter() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前明月亮"
        )
        #expect(result.accuracy == 0.8)
        #expect(result.correctCount == 4)
        #expect(result.wrongCount == 1)
        #expect(result.alignedChars.filter { $0.status == .wrong }.count == 1)
    }

    @Test("漏字被标记为missing")
    func missingCharacter() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前月光"
        )
        #expect(result.correctCount == 4)
        #expect(result.missingCount == 1)
        #expect(result.accuracy == 0.8)
    }

    @Test("多字被标记为extra")
    func extraCharacter() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前明月大光"
        )
        #expect(result.correctCount == 5)
        #expect(result.extraCount == 1)
        #expect(result.accuracy == 1.0)
    }

    @Test("声调不同视为正确")
    func toneTolerance() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前明月广"
        )
        #expect(result.accuracy == 1.0)
        #expect(result.correctCount == 5)
    }

    @Test("完全无关内容返回0%正确率")
    func completelyWrong() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "天地玄黄宇宙洪荒"
        )
        #expect(result.accuracy == 0.0)
    }

    @Test("空识别结果")
    func emptyRecognized() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: ""
        )
        #expect(result.accuracy == 0.0)
        #expect(result.missingCount == 5)
    }

    @Test("标点符号被忽略")
    func punctuationIgnored() async {
        let result = await RecitationChecker.check(
            original: "床前明月光，疑是地上霜。",
            recognized: "床前明月光疑是地上霜"
        )
        #expect(result.accuracy == 1.0)
        #expect(result.correctCount == 10)
    }

    @Test("多错误混合场景")
    func mixedErrors() async {
        let result = await RecitationChecker.check(
            original: "床前明月光",
            recognized: "床前月大光"
        )
        #expect(result.missingCount >= 1)
        #expect(result.extraCount >= 1)
    }
}
