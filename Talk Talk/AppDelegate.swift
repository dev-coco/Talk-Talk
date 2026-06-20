import Cocoa
import SwiftUI
import Speech

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private let speechManager = SpeechManager()
    private let correctionManager = CorrectionManager()
    
    private var settingsWindow: NSWindow?
    private var globalMonitor: Any?
    private var isProcessing = false
    private var isRecording = false
    
    private var lastKeyState = false
    private var keyDownTimestamp: Date? // 记录按下时间

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化菜单栏按钮
        setupStatusItem()
        
        // 申请语音识别权限
        SFSpeechRecognizer.requestAuthorization { _ in }
        
        // 开启全局快捷键监听
        setupKeyMonitoring()
    }

    // 菜单栏设置
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button { button.title = "🎙️" }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_settings", comment: ""), action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_quit", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        statusItem?.menu = menu
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.center()
            window.title = NSLocalizedString("menu_settings", comment: "")
            window.contentView = NSHostingView(rootView: SettingsView(correctionManager: self.correctionManager))
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // 键盘监听
    func setupKeyMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return }
            
            let savedKey = UserDefaults.standard.integer(forKey: "selectedKey")
            let targetKey = (savedKey == 0) ? 63 : savedKey
            let mode = UserDefaults.standard.integer(forKey: "triggerMode")
            
            guard Int(event.keyCode) == targetKey else { return }

            // 获取当前物理按键状态
            let isPressed: Bool
            if targetKey == 63 || (targetKey >= 54 && targetKey <= 62) {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                isPressed = flags.rawValue != 0 || (targetKey == 63 && event.modifierFlags.contains(.function))
            } else {
                isPressed = (event.type == .keyDown)
            }

            if mode == 1 {
                // 点击模式
                if isPressed && !self.lastKeyState {
                    // 按下快捷键时记录时间
                    self.keyDownTimestamp = Date()
                } else if !isPressed && self.lastKeyState {
                    // 松开按键时计算持续时间
                    if let start = self.keyDownTimestamp {
                        let duration = Date().timeIntervalSince(start)
                        
                        // 设置延时，避免误触发
                        if duration > 0.15 {
                            if self.isRecording {
                                self.stopRecordingSession()
                            } else {
                                self.startRecordingSession()
                            }
                        }
                    }
                    self.keyDownTimestamp = nil
                }
                self.lastKeyState = isPressed
            } else {
                // 按住模式
                if isPressed {
                    self.startRecordingSession()
                } else {
                    self.stopRecordingSession()
                }
            }
        }
    }

    // 录音控制
    private func startRecordingSession() {
        // 防止重复触发录音逻辑
        guard !isRecording else { return }
        isRecording = true
        
        let lang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "auto"
        if lang == "auto" {
            let primaryLang = Locale.preferredLanguages.first ?? "zh-CN"
            speechManager.languageCode = primaryLang.hasPrefix("zh") ? "zh-CN" : (primaryLang.hasPrefix("en") ? "en-US" : primaryLang)
        } else {
            speechManager.languageCode = lang
        }

        speechManager.contextualStrings = correctionManager.contextualStrings
        
        // 直接开始，回调闭包设为空
        speechManager.startRecording { _ in }
    }

    private func stopRecordingSession() {
        guard isRecording else { return }
        isRecording = false
        
        // 停止识别并处理结果
        speechManager.stopRecording { [weak self] finalResult in
            guard let self = self else { return }
            
            let text = finalResult.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !text.isEmpty && !self.isProcessing {
                self.processAndPaste(text: text)
            }
        }
    }

    // 文本处理链
    private func processAndPaste(text: String) {
        self.isProcessing = true
        
        let correctedText = correctionManager.applyCorrections(to: text)
        let targetLang = UserDefaults.standard.string(forKey: "targetTranslationLanguage") ?? "None"
        
        if targetLang != "None" {
            TranslationManager.shared.translate(correctedText, to: targetLang) { [weak self] translated in
                self?.performPaste(text: translated)
                self?.isProcessing = false
            }
        } else {
            self.performPaste(text: correctedText)
            self.isProcessing = false
        }
    }

    private func performPaste(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return }

        self.simulateCommandV()
    }
    
    private func simulateCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}
