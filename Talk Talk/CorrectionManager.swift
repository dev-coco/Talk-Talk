import Foundation
import Combine
import AppKit

// 智能纠错
class CorrectionManager: ObservableObject {
    @Published var keywords: [String] {
        didSet {
            // 每次修改时立即保存
            UserDefaults.standard.set(keywords, forKey: "asr_keywords")
        }
    }
        
    init() {
        // 启动时从本地存储加载已保存的词汇
        self.keywords = UserDefaults.standard.stringArray(forKey: "asr_keywords") ?? []
    }

    // 提供给语音识别引擎的上下文词汇
    var contextualStrings: [String] { return keywords }

    func applyCorrections(to text: String) -> String {
        // 如果没有关键词，返回原文本，不用纠错
        guard !keywords.isEmpty && !text.isEmpty else {
            return text
        }
        
        var result = text
        
        // 按字符长度从长到短排序，防止短词破坏长词匹配
        let sortedKeywords = keywords.sorted { $0.count > $1.count }
        
        for targetWord in sortedKeywords {
            let targetPinyin = targetWord.pinyinArray
            let wordLen = targetWord.count
            let nsResult = result as NSString
            
            if nsResult.length < wordLen { continue }
            
            var i = 0
            while i <= (nsResult.length - wordLen) {
                let range = NSRange(location: i, length: wordLen)
                let subString = nsResult.substring(with: range)
                
                // 判断截取的文本与目标词的拼音是否高度相似
                if isPhoneticallySimilar(subString.pinyinArray, targetPinyin) {
                    // 如果拼音一样但文字不一样（说明识别错了），需要进行替换
                    if subString != targetWord {
                        result = (result as NSString).replacingCharacters(in: range, with: targetWord)
                        i += wordLen; continue // 替换后跳过该词长度，继续扫描
                    }
                }
                i += 1
            }
        }
        return result
    }

    // 判断两个拼音数组是否高度相似
    // 用来处理 guo/gou, xiao/xian 等容易混淆的拼音
    private func isPhoneticallySimilar(_ p1: [String], _ p2: [String]) -> Bool {
        guard p1.count == p2.count else { return false }
        
        for (a, b) in zip(p1, p2) {
            if a == b { continue }
            
            // 检查声母：首字母必须相同
            let commonPrefix = String(a.prefix(1))
            if commonPrefix != String(b.prefix(1)) { return false }
            
            // 检查韵母差异度
            let diffCount = zip(a, b).filter{ $0 != $1 }.count + abs(a.count - b.count)
            if diffCount > 2 { return false }
        }
        return true
    }
}

// 拼音转换工具
extension String {
    // 将字符串转换为不带声调的拼音数组
    var pinyinArray: [String] {
        return self.map { char -> String in
            let mutableString = NSMutableString(string: String(char))
            // 转为带声调的拉丁字母
            CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
            // 去掉声调符号
            CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
            // 转为小写并去除多余空格
            return (mutableString as String).lowercased().replacingOccurrences(of: " ", with: "")
        }
    }
}
