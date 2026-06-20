import Foundation
import Speech
import Combine

// 语音识别管理器
class SpeechManager: ObservableObject {
    // 用于管理音频硬件和音频处理链
    private let audioEngine = AVAudioEngine()
    // 负责配置识别参数
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    // 语音识别任务
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // 配置参数
    var languageCode: String = "zh-CN" // 识别语言代码
    var contextualStrings: [String] = [] // 注入词库
    private var lastText: String = "" // 用于记录实时识别结果
    
    // 状态标识：标记用户是否已经松开了按键
    private var isWaitingForFinalResult: Bool = false
    // 存储最终回调闭包
    private var finalCompletionHandler: ((String) -> Void)?

    // 开始录音并实时回调识别结果
    func startRecording(completion: @escaping (String) -> Void) {
        // 在开始新任务前，清空上一次的记录
        self.lastText = ""
        
        // 彻底清理旧任务，防止多任务冲突
        recognitionTask?.cancel()
        recognitionTask = nil
        isWaitingForFinalResult = false
        finalCompletionHandler = nil
        
        // 重置音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.reset()
        }

        // 初始化识别器
        let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let request = recognitionRequest, let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("识别器不可用，请检查权限设置")
            return
        }
        
        // 配置识别请求参数
        request.requiresOnDeviceRecognition = false
        // 注入你的自定义词库
        request.contextualStrings = contextualStrings
        request.shouldReportPartialResults = true
        // 自动添加标点符号
        request.addsPunctuation = true
        
        // 配置麦克风输入节点
        let inputNode = audioEngine.inputNode
        // 获取麦克风输入的音频格式
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        
        // 启动识别任务
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("识别错误: \(error.localizedDescription)")
                // 如果出错，强制清理并结束
                self.handleFinalStep()
                return
            }
            
            // 获得识别结果
            if let result = result {
                let formattedString = result.bestTranscription.formattedString
                // 只有新文本产生时，才更新 lastText
                self.lastText = formattedString
                
                // 如果任务还没结束，执行实时预览回调
                if !result.isFinal {
                    completion(formattedString)
                }
                
                // 检测到 isFinal 说明引擎处理完毕
                if result.isFinal {
                    self.handleFinalStep()
                }
            }
        }
        
        do {
            // 启动音频引擎硬件
            try audioEngine.start()
        } catch {
            print("音频引擎无法启动: \(error)")
        }
    }

    // 停止录音并返回最终确定的文本
    func stopRecording(finalCompletion: @escaping (String) -> Void) {
        // 即使引擎没运行，也需要清理状态，防止逻辑挂起
        guard audioEngine.isRunning else {
            // 如果误触或快速点击导致引擎没起来，直接返回空并清理
            finalCompletion("")
            return
        }
        
        // 停止物理音频采集
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 标记当前正在等待引擎最后的汇总
        self.isWaitingForFinalResult = true
        self.finalCompletionHandler = finalCompletion
        
        // 结束音频流
        recognitionRequest?.endAudio()
    }
    
    // 当 isFinal 达成或出错时执行
    private func handleFinalStep() {
        // 停止录音后才触发最终回调
        if isWaitingForFinalResult {
            // 返回本次识别到的文本
            finalCompletionHandler?(self.lastText)
            
            // 清空记录
            self.lastText = ""
            
            // 重置所有状态
            isWaitingForFinalResult = false
            finalCompletionHandler = nil
            
            // 彻底重置硬件，准备下一次使用
            audioEngine.reset()
            recognitionRequest = nil
            recognitionTask = nil
        }
    }
}
