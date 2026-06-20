import SwiftUI
import Speech
import ServiceManagement
import Carbon

struct SettingsView: View {
    // 识别语言，默认自动检测
    @AppStorage("selectedLanguage") private var selectedLanguage = "auto"
    // 触发按键，默认 Fn
    @AppStorage("selectedKey") private var selectedKey = 63
    // 修饰键
    @AppStorage("selectedModifiers") private var selectedModifiers = 0
    // 快捷键显示的名称
    @AppStorage("selectedKeyName") private var selectedKeyName = "Fn"
    // 翻译功能
    @AppStorage("targetTranslationLanguage") private var targetTranslationLanguage = "None"
    
    // 0: 按住说话
    // 1: 点击切换
    @AppStorage("triggerMode") private var triggerMode = 0
    
    // 词典管理对象
    @ObservedObject var correctionManager = CorrectionManager()
    // 录制快捷键状态
    @State private var isRecordingKey = false
    // 词库新增词汇的输入框文本
    @State private var newKeyword = ""
    // 系统支持的语言识别语言列表
    @State private var supportedLocales: [Locale] = []
    // 当前选中的标签页
    @State private var currentTab: String = NSLocalizedString("nav_general", comment: "")

    // 开机启动
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack(spacing: 0) {
            // 左侧边栏
            VStack(alignment: .leading, spacing: 5) {
                SidebarItem(title: NSLocalizedString("nav_general", comment: ""), icon: "gearshape.fill", isSelected: currentTab == NSLocalizedString("nav_general", comment: "")) { currentTab = NSLocalizedString("nav_general", comment: "") }
                SidebarItem(title: NSLocalizedString("nav_lexicon", comment: ""), icon: "text.book.closed.fill", isSelected: currentTab == NSLocalizedString("nav_lexicon", comment: "")) { currentTab = NSLocalizedString("nav_lexicon", comment: "") }
                Spacer()
            }
            .padding(.vertical, 20).padding(.horizontal, 8)
            .frame(width: 150, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()

            // 右侧内容区
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        if currentTab == NSLocalizedString("nav_general", comment: "") {
                            // 常规设置面板
                            VStack(alignment: .leading, spacing: 18) {
                                Text("label_speech_recognition").font(.headline)
                                
                                HStack {
                                    Label("label_recognition_language", systemImage: "character.bubble")
                                    Spacer()
                                    Picker("", selection: $selectedLanguage) {
                                        Text("option_auto_detect").tag("auto")
                                        Divider()
                                        ForEach(supportedLocales, id: \.identifier) { locale in
                                            // 显示语音本地化名称
                                            Text(locale.localizedString(forIdentifier: locale.identifier)?.capitalized ?? locale.identifier).tag(locale.identifier)
                                        }
                                    }.frame(width: 220).labelsHidden()
                                }
                                
                                // 开机自动启动开关
                                HStack {
                                    Label("toggle_launch_at_login", systemImage: "power")
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { launchAtLogin },
                                        set: { toggleLaunchAtLogin(enabled: $0) }
                                    )).toggleStyle(.switch).labelsHidden()
                                }
                                
                                HStack {
                                    Label("label_trigger_key", systemImage: "keyboard")
                                    Spacer()
                                    Button(action: { isRecordingKey = true }) {
                                        Text(isRecordingKey ? "label_press_key_prompt" : selectedKeyName)
                                            .frame(width: 120)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(isRecordingKey ? .red : .blue)
                                        .background(KeyEventView(isRecording: $isRecordingKey, selectedKey: $selectedKey, selectedModifiers: $selectedModifiers, selectedKeyName: $selectedKeyName))
                                    }
                                
                                HStack(alignment: .center) {
                                    // 提示文字
                                    Text(triggerMode == 0 ? "tips_hold" : "tips_click")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 0)
                                        
                                    Spacer() // 自动撑开中间空间
    
                                    // 模式切换
                                    Picker("", selection: $triggerMode) {
                                        Text("hold").tag(0)
                                        Text("click").tag(1)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 135)
                                    .labelsHidden()
                                }

                                Divider().padding(.vertical, 5)

                                Text("section_translation").font(.headline)
                                HStack {
                                    Label("label_translation_lang", systemImage: "translate")
                                    Spacer()
                                    Picker("", selection: $targetTranslationLanguage) {
                                        Text("option_no_translation").tag("None")
                                        Divider()
                                        Text("lang_en").tag("en")
                                        Text("lang_zh_cn").tag("zh-CN")
                                        Text("lang_es").tag("es")
                                        Text("lang_fr").tag("fr")
                                        Text("lang_ja").tag("ja")
                                        Text("lang_pt").tag("pt")
                                        Text("lang_de").tag("de")
                                        Text("lang_ru").tag("ru")
                                        Text("lang_hi").tag("hi")
                                        Text("lang_ko").tag("ko")
                                        Text("lang_it").tag("it")
                                        Text("lang_tr").tag("tr")
                                        Text("lang_hu").tag("hu")
                                    }.frame(width: 220).labelsHidden()
                                }
                            }
                        } else {
                            // 词库管理面板
                            VStack(alignment: .leading, spacing: 15) {
                                Text("label_lexicon_management").font(.headline)
                                HStack {
                                    TextField("placeholder_add_word", text: $newKeyword).textFieldStyle(.roundedBorder).onSubmit { addWord() }
                                    Button(action: addWord) { Image(systemName: "plus") }.buttonStyle(.bordered)
                                }
                                ScrollView(.vertical) {
                                    // 自定义流式布局，展示所有词汇标签
                                    FlowLayout(items: correctionManager.keywords) { word in
                                        TagView(word: word) { removeWord(word) }
                                    }.padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                                .frame(minHeight: 250)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.2)).cornerRadius(8)
                            }
                        }
                    }.padding(25)
                }
                
                Divider()
                HStack {
                    Spacer()
                    Button("btn_done") { NSApplication.shared.keyWindow?.close() }.buttonStyle(.borderedProminent).controlSize(.large)
                }.padding(16)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 650, height: 500)
        .onAppear { loadLocales() } // 页面出现时加载语言列表
    }

    // 控制 macOS 开启启动
    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                // 注册自启服务
                try SMAppService.mainApp.register()
            } else {
                // 注销自启服务
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch { print("设置失败: \(error)") }
    }
    
    // 添加词汇到词库
    private func addWord() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !correctionManager.keywords.contains(trimmed) {
            correctionManager.keywords.append(trimmed)
            newKeyword = ""
        }
    }
    
    // 删除词库
    private func removeWord(_ word: String) { correctionManager.keywords.removeAll { $0 == word } }
    
    // 获取系统 Speech 框架支持的所有语言
    private func loadLocales() {
        SFSpeechRecognizer.requestAuthorization { _ in
            DispatchQueue.main.async {
                let locales = SFSpeechRecognizer.supportedLocales()
                self.supportedLocales = locales.sorted { ($0.localizedString(forIdentifier: $0.identifier) ?? "") < ($1.localizedString(forIdentifier: $1.identifier) ?? "") }
            }
        }
    }
}


struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            
            // 固定图标宽度以保证文本对齐
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 20)
            
            // 选中标题时加粗
            Text(title).font(.system(size: 13, weight: isSelected ? .medium : .regular))
            
            Spacer()
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        // 选中时显示浅蓝色背景，未选中时透明
        .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
        .cornerRadius(8)
        // 选中时文字图标变蓝，未选中时保持原色
        .foregroundColor(isSelected ? .blue : .primary)
        // 允许在透明区域点击
        .contentShape(Rectangle())
        .onTapGesture { action() }
    }
}

struct TagView: View {
    let word: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(word).font(.system(size: 12))
            
            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1)) // 浅蓝色气泡背景
        .cornerRadius(6)
    }
}

struct FlowLayout<T: Hashable, V: View>: View {
    let items: [T]
    let content: (T) -> V
    @State private var totalHeight = CGFloat.zero
    
    var body: some View {
        VStack {
            GeometryReader {
                // 在内部闭包中计算所有元素的位置
                geometry in self.generateContent(in: geometry)
            }
        }
        // GeometryReader 会撑满父容器，需要设置计算高度
        .frame(height: totalHeight)
    }
    
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero // 累加当前行宽
        var height = CGFloat.zero // 累加当前行高
        
        return ZStack(alignment: .topLeading) {
            ForEach(self.items, id: \.self) { item in
                self.content(item)
                    .padding(4)
                    // 通过对齐导线计算水平偏移
                    .alignmentGuide(.leading) { d in
                        // 如果当前累加宽度 + 元素宽度 > 容器宽度，则换行
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height // 换行后，高度向下累加
                        }
                    let result = width
                
                    // 如果不是最后一个元素，更新 width 给下一个元素使用
                    if item == self.items.last {
                        width = 0
                    } else {
                        width -= d.width
                    }
                    return result
                }
                // 通过对齐导线计算垂直偏移
                .alignmentGuide(.top) { d in
                    let result = height
                    // 当处理到最后一个元素时，异步更新总高度，通知父视图调整大小
                    if item == self.items.last {
                        DispatchQueue.main.async {
                            self.totalHeight = abs(height - d.height)
                        }
                        height = 0
                    }
                    return result
                }
            }
        }
    }
}

struct KeyEventView: NSViewRepresentable {
    @Binding var isRecording: Bool; @Binding var selectedKey: Int; @Binding var selectedModifiers: Int; @Binding var selectedKeyName: String
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // 添加局部事件监听器：监听按键按下和修饰键改变
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if isRecording {

                // 获取当前的修饰键（Cmd, Alt, Shift, Ctrl）
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

                // 处理普通按键按下
                if event.type == .keyDown {
                    DispatchQueue.main.async {
                        self.selectedKey = Int(event.keyCode); self.selectedModifiers = Int(modifiers.rawValue)
                        self.selectedKeyName = self.getFriendlyName(event: event); self.isRecording = false
                    }
                    return nil
                }
                
                // 处理特殊功能键
                if event.type == .flagsChanged && modifiers.rawValue == 0 {
                    let keyCode = event.keyCode
                    if [63, 54, 55, 56, 60, 59, 62, 58, 61].contains(keyCode) {
                        DispatchQueue.main.async {
                            self.selectedKey = Int(keyCode); self.selectedModifiers = 0
                            self.selectedKeyName = self.getSimpleKeyName(keyCode: keyCode); self.isRecording = false
                        }
                    }
                }
            }
            return event
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    // 将按键事件转为文本显示
    func getFriendlyName(event: NSEvent) -> String {
        var name = ""; let flags = event.modifierFlags
        if flags.contains(.control) { name += "⌃ " }
        if flags.contains(.option) { name += "⌥ " }
        if flags.contains(.shift) { name += "⇧ " }
        if flags.contains(.command) { name += "⌘ " }
        name += getSimpleKeyName(keyCode: event.keyCode)
        return name
    }
    
    // 处理特殊键的映射表
    func getSimpleKeyName(keyCode: UInt16) -> String {
        let mapping: [UInt16: String] = [
            63: "Fn", 54: "R⌘", 55: "L⌘", 56: "L⇧", 60: "R⇧",
            59: "L⌃", 62: "R⌃", 58: "L⌥", 61: "R⌥", 49: "Space",
            36: "Return", 53: "Esc", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        if let special = mapping[keyCode] { return special }
        return keyCodeToChar(keyCode: keyCode) ?? "\(keyCode)"
    }
    
    // 利用 Carbon 框架将 KeyCode 转换为当前键盘布局下的字符
    private func keyCodeToChar(keyCode: UInt16) -> String? {
        let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let dataPtr = unsafeBitCast(layoutData, to: CFData.self)
        let layoutPtr = CFDataGetBytePtr(dataPtr)
        var deadKeyState: UInt32 = 0
        let maxLength = 4;
        var unicodeString = [UniChar](repeating: 0, count: maxLength)
        var actualLength = 0
        
        UCKeyTranslate(unsafeBitCast(layoutPtr, to: UnsafePointer<UCKeyboardLayout>.self),
                       keyCode, UInt16(kUCKeyActionDown), 0,
                       UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                       &deadKeyState, maxLength, &actualLength, &unicodeString)
        
        if String(utf16CodeUnits: unicodeString, count: actualLength).isEmpty { return nil }
        return String(utf16CodeUnits: unicodeString, count: actualLength).uppercased()
    }
}
