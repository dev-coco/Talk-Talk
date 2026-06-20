import SwiftUI
import ApplicationServices

struct PermissionManager {
    // 检查并触发系统原生的辅助功能权限对话框
    static func checkAndPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
