import Testing
import Foundation
@testable import chinese_poetry

struct PinyinHelperTests {
    @Test("stripTone 去除声调标记")
    func stripToneRemovesDiacritics() async {
        #expect(await PinyinHelper.stripTone("chuáng") == "chuang")
        #expect(await PinyinHelper.stripTone("qián") == "qian")
        #expect(await PinyinHelper.stripTone("guāng") == "guang")
        #expect(await PinyinHelper.stripTone("guǎng") == "guang")
    }

    @Test("pinyin 返回汉字拼音")
    func pinyinReturnsPinyin() async {
        let result = await PinyinHelper.pinyin(for: "床")
        #expect(result != nil)
    }

    @Test("pinyin 应用多音字修正")
    func pinyinAppliesCorrections() async {
        #expect(await PinyinHelper.pinyin(for: "还") == "hái")
        #expect(await PinyinHelper.pinyin(for: "重") == "chóng")
    }
}
