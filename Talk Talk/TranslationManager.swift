import Foundation

class TranslationManager {
    // 单例对象，确保全局唯一
    static let shared = TranslationManager()
    
    // 私有化构造函数
    private init() {}
    
    // 执行翻译任务
    // - Parameters:
    //   - text: 需要翻译的原文本
    //   - targetLang: 目标语言代码（如 "en", "zh-CN", "ja"）
    //   - completion: 翻译完成后的回调闭包，返回翻译后的字符串
    func translate(_ text: String, to targetLang: String, completion: @escaping (String) -> Void) {
        if targetLang == "None" || text.isEmpty {
            completion(text); return
        }
        
        // 转换成 URL 编码
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(text); return
        }
        
        // Google 翻译 API
        let urlString = "https://translate.google.com/translate_a/single?client=gtx&dt=t&dj=1&ie=UTF-8&sl=auto&tl=\(targetLang)&q=\(encodedText)"
        
        guard let url = URL(string: urlString) else {
            completion(text); return
        }
        
        // 发送异步网络请求
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(text) }
                return
            }
            
            do {
                // 解析 JSON
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let sentences = json["sentences"] as? [[String: Any]] {
                    
                    // 提取所有分句的翻译并拼接
                    let result = sentences.compactMap { $0["trans"] as? String }.joined()
                    DispatchQueue.main.async { completion(result) }
                } else {
                    // 解析失败则返回原文本
                    DispatchQueue.main.async { completion(text) }
                }
            } catch {
                DispatchQueue.main.async { completion(text) }
            }
        }.resume()
    }
}
