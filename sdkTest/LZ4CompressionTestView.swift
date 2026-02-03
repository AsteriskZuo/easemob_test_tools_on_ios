//
//  LZ4CompressionTestView.swift
//  sdkTest
//
//  Created by Antigravity on 2026/02/02.
//

import SwiftUI
import HyphenateChat
import UniformTypeIdentifiers

// MARK: - Global Log Collector

/// 全局日志收集器，实时过滤 LZ4 压缩日志并流式写入文件
// 压缩日志示例：`[0][2026/02/02 13:51:48:144(08)]: log: level: 0, area: 4, LZ4 compress success: compressed size=13 bytes, original size=19, ratio=68.421051 %, compress_ratio_<100%=9, compress_ratio_>=100%=3`
// 解压缩日志示例：`[0][2026/02/02 13:54:40:004(08)]: log: level: 0, area: 1, LZ4 decompress success: compressed size=497 bytes, decompressed size=606, ratio=82.013199 %, compress_ratio_<100%=2, compress_ratio_>=100%=2`
class LZ4LogCollector {
    static let shared = LZ4LogCollector()
    
    private let queue = DispatchQueue(label: "com.lz4.logcollector")
    private var fileHandle: FileHandle?
    private var outputPath: String = ""
    private var isCollecting: Bool = false
    private(set) var entryCount: Int = 0
    private var headerWritten: Bool = false
    
    // 统计数据
    private var totalCompressedSize: Int = 0
    private var totalOriginalSize: Int = 0
    
    // 正则表达式（预编译）
    // 压缩或者解压缩日志
    private let lz4Pattern = try? NSRegularExpression(
        pattern: #"LZ4 compress success: compressed size=(\d+) bytes, original size=(\d+), ratio=([\d.]+) %|LZ4 decompress success: compressed size=(\d+) bytes, decompressed size=(\d+), ratio=([\d.]+) %"#,
        options: []
    )
    private let timestampPattern = try? NSRegularExpression(
        pattern: #"\[(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}:\d{3})"#,
        options: []
    )
    
    private init() {}
    
    /// 开始收集，指定输出文件路径
    func startCollecting(outputPath: String) -> Bool {
        return queue.sync {
            self.outputPath = outputPath
            self.entryCount = 0
            self.headerWritten = false
            self.totalCompressedSize = 0
            self.totalOriginalSize = 0
            
            // 创建或清空输出文件
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: outputPath) {
                try? fileManager.removeItem(atPath: outputPath)
            }
            
            if fileManager.createFile(atPath: outputPath, contents: nil, attributes: nil) {
                self.fileHandle = FileHandle(forWritingAtPath: outputPath)
                self.isCollecting = true
                return true
            }
            return false
        }
    }
    
    /// 停止收集并完成文件
    func stopCollecting() -> (success: Bool, entryCount: Int, outputPath: String) {
        return queue.sync {
            guard isCollecting else {
                return (false, 0, "")
            }
            
            // 写入汇总统计（如果有数据）
            if entryCount > 0 {
                let avgRatio = totalOriginalSize > 0 ? Double(totalCompressedSize) / Double(totalOriginalSize) * 100.0 : 0.0
                let footer = """
                
                ## 统计汇总
                
                | 统计项 | 值 |
                | --- | --- |
                | 总条数 | \(entryCount) |
                | 压缩后总大小 | \(totalCompressedSize) bytes |
                | 压缩前总大小 | \(totalOriginalSize) bytes |
                | 平均压缩率 | \(String(format: "%.2f", avgRatio))% |
                
                - 生成时间: \(Date())
                
                """
                if let data = footer.data(using: .utf8) {
                    fileHandle?.write(data)
                }
            } else {
                let noData = "# LZ4 压缩统计报告\n\n> 未收集到任何 LZ4 压缩日志\n"
                if let data = noData.data(using: .utf8) {
                    fileHandle?.write(data)
                }
            }
            
            try? fileHandle?.close()
            fileHandle = nil
            isCollecting = false
            
            let result = (true, entryCount, outputPath)
            return result
        }
    }
    
    /// 收集日志行（由 EMLogDelegate 调用），实时过滤 LZ4 相关日志并写入统计文件
    func collectLog(_ log: String) {
        queue.async { [weak self] in
            guard let self = self, self.isCollecting else { return }
            
            // 快速过滤：只处理包含 LZ4 关键字的日志
            guard log.contains("LZ4 compress success") || log.contains("LZ4 decompress success") else { return }
            
            // 解析日志
            guard let entry = self.parseLogLine(log) else { return }
            
            // 写入表头（仅第一次）
            if !self.headerWritten {
                let header = """
                # LZ4 压缩统计报告

                | 时间 | Compressed Size | Original Size | Ratio |
                | --- | --- | --- | --- |

                """
                if let data = header.data(using: .utf8) {
                    self.fileHandle?.write(data)
                }
                self.headerWritten = true
            }
            
            // 写入表格行
            let row = "| \(entry.timestamp) | \(entry.compressedSize) | \(entry.originalSize) | \(String(format: "%.2f", entry.ratio))% |\n"
            if let data = row.data(using: .utf8) {
                self.fileHandle?.write(data)
            }
            
            self.entryCount += 1
            self.totalCompressedSize += entry.compressedSize
            self.totalOriginalSize += entry.originalSize
        }
    }
    
    /// 解析日志行
    private func parseLogLine(_ line: String) -> (timestamp: String, compressedSize: Int, originalSize: Int, ratio: Double)? {
        guard let lz4Pattern = lz4Pattern else { return nil }
        
        let range = NSRange(line.startIndex..., in: line)
        guard let match = lz4Pattern.firstMatch(in: line, options: [], range: range) else { return nil }
        
        // 提取时间戳
        var timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        if let tsPattern = timestampPattern,
           let tsMatch = tsPattern.firstMatch(in: line, options: [], range: range),
           let tsRange = Range(tsMatch.range(at: 1), in: line) {
            timestamp = String(line[tsRange])
        }
        
        // 提取数值 - 处理两种模式的捕获组
        // 压缩: 捕获组 1-3, 解压缩: 捕获组 4-6
        var compressedSize: Int = 0
        var originalSize: Int = 0
        var ratio: Double = 0.0
        
        if match.range(at: 1).location != NSNotFound,
           let compressedRange = Range(match.range(at: 1), in: line),
           let originalRange = Range(match.range(at: 2), in: line),
           let ratioRange = Range(match.range(at: 3), in: line) {
            // 压缩日志
            compressedSize = Int(line[compressedRange]) ?? 0
            originalSize = Int(line[originalRange]) ?? 0
            ratio = Double(line[ratioRange]) ?? 0.0
        } else if match.range(at: 4).location != NSNotFound,
                  let compressedRange = Range(match.range(at: 4), in: line),
                  let originalRange = Range(match.range(at: 5), in: line),
                  let ratioRange = Range(match.range(at: 6), in: line) {
            // 解压缩日志
            compressedSize = Int(line[compressedRange]) ?? 0
            originalSize = Int(line[originalRange]) ?? 0
            ratio = Double(line[ratioRange]) ?? 0.0
        } else {
            return nil
        }
        
        return (timestamp, compressedSize, originalSize, ratio)
    }
    
    /// 获取当前收集数量
    var count: Int {
        return queue.sync { entryCount }
    }
    
    /// 是否正在收集
    var collecting: Bool {
        return queue.sync { isCollecting }
    }
    
    /// 清空状态（不停止收集）
    func reset() {
        queue.async {
            self.entryCount = 0
            self.totalCompressedSize = 0
            self.totalOriginalSize = 0
        }
    }
}

// MARK: - Data Models

/// 日志统计条目
struct LZ4StatEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let compressedSize: Int
    let originalSize: Int
    let ratio: Double
}

/// 从 JSON 文件读取的消息数据
struct MessageData {
    let action: String
    let rawJson: String
}

// MARK: - Streaming File Reader

/// 流式文件读取器，逐行读取大文件，避免内存溢出
class StreamingFileReader {
    private var fileHandle: FileHandle?
    private var buffer: Data = Data()
    private let chunkSize: Int = 4096  // 每次读取 4KB
    private let delimiter: Data = "\n".data(using: .utf8)!
    private var isEOF: Bool = false
    private var currentFilePath: String = ""
    
    /// 打开文件
    func open(path: String) -> Bool {
        close()
        currentFilePath = path
        fileHandle = FileHandle(forReadingAtPath: path)
        isEOF = false
        buffer = Data()
        return fileHandle != nil
    }
    
    /// 关闭文件
    func close() {
        try? fileHandle?.close()
        fileHandle = nil
        buffer = Data()
        isEOF = false
    }
    
    /// 读取下一行
    func readLine() -> String? {
        guard let fileHandle = fileHandle else { return nil }
        
        while true {
            // 查找缓冲区中的换行符
            if let range = buffer.range(of: delimiter) {
                let lineData = buffer.subdata(in: 0..<range.lowerBound)
                buffer.removeSubrange(0..<range.upperBound)
                return String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // 如果已经到达文件末尾
            if isEOF {
                if buffer.isEmpty {
                    return nil
                } else {
                    // 返回缓冲区中剩余的内容
                    let remaining = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    buffer = Data()
                    return remaining?.isEmpty == true ? nil : remaining
                }
            }
            
            // 读取更多数据
            let newData = fileHandle.readData(ofLength: chunkSize)
            if newData.isEmpty {
                isEOF = true
            } else {
                buffer.append(newData)
            }
        }
    }
    
    /// 重置到文件开头
    func reset() {
        fileHandle?.seek(toFileOffset: 0)
        buffer = Data()
        isEOF = false
    }
    
    deinit {
        close()
    }
}

/// 文件队列管理器，管理多个文件的流式读取
class FileQueueManager {
    private var filePaths: [String] = []
    private var currentFileIndex: Int = 0
    private let reader = StreamingFileReader()
    private(set) var totalLinesRead: Int = 0
    private(set) var isReady: Bool = false
    
    /// 准备文件队列
    func prepare(folderPath: String) -> (success: Bool, fileCount: Int, error: String?) {
        reset()
        
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: folderPath) else {
            return (false, 0, "文件夹不存在: \(folderPath)")
        }
        
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: folderPath, isDirectory: &isDirectory)
        
        if isDirectory.boolValue {
            do {
                let files = try fileManager.contentsOfDirectory(atPath: folderPath)
                for file in files {
                    if file.hasPrefix(".") { continue }
                    let fullPath = "\(folderPath)/\(file)"
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) && !isDir.boolValue {
                        filePaths.append(fullPath)
                    }
                }
            } catch {
                return (false, 0, "读取目录失败: \(error.localizedDescription)")
            }
        } else {
            filePaths.append(folderPath)
        }
        
        if filePaths.isEmpty {
            return (false, 0, "没有找到可读取的文件")
        }
        
        // 打开第一个文件
        if reader.open(path: filePaths[0]) {
            isReady = true
            return (true, filePaths.count, nil)
        } else {
            return (false, 0, "无法打开文件: \(filePaths[0])")
        }
    }
    
    /// 读取下一行（跨文件）
    func readNextLine() -> String? {
        guard isReady else { return nil }
        
        while currentFileIndex < filePaths.count {
            if let line = reader.readLine() {
                if !line.isEmpty {
                    totalLinesRead += 1
                    return line
                }
                continue
            }
            
            // 当前文件读取完毕，切换到下一个文件
            currentFileIndex += 1
            if currentFileIndex < filePaths.count {
                if !reader.open(path: filePaths[currentFileIndex]) {
                    continue  // 打开失败，跳过这个文件
                }
            }
        }
        
        return nil
    }
    
    /// 重置队列
    func reset() {
        reader.close()
        filePaths.removeAll()
        currentFileIndex = 0
        totalLinesRead = 0
        isReady = false
    }
    
    /// 获取当前文件索引
    var currentFileNumber: Int {
        return currentFileIndex + 1
    }
    
    /// 获取文件总数
    var totalFiles: Int {
        return filePaths.count
    }
}

// MARK: - Log Delegate

class LZ4CompressionLogDelegate: NSObject, EMLogDelegate {
    func logDidOutput(_ log: String) {
        LZ4LogCollector.shared.collectLog(log)
    }
}

// MARK: - View Model

class LZ4CompressionTestViewModel: ObservableObject {
    // MARK: - SDK Settings
    @Published var isSDKInitialized: Bool = false
    @Published var sdkStatus: String = "未初始化"
    
    // MARK: - Account Settings
    @Published var appKey: String = "easemob-demo#testngi01"
    @Published var username: String = "tst"
    @Published var password: String = "1"
    @Published var isLoggedIn: Bool = false
    @Published var loginStatus: String = "未登录"
    
    // MARK: - File Settings
    @Published var folderPath: String = ""
    @Published var targetUserId: String = "tst01"
    @Published var outputDirectory: String = ""
    
    // MARK: - Send Settings
    @Published var sendInterval: Int = 1000 // 毫秒
    @Published var isSending: Bool = false
    @Published var currentIndex: Int = 0
    @Published var totalMessages: Int = 0
    @Published var sendStatus: String = ""
    
    // MARK: - Statistics
    @Published var statEntries: [LZ4StatEntry] = []
    @Published var statisticsPreview: String = ""
    
    // MARK: - Log
    @Published var logText: String = ""
    
    // MARK: - Private Properties
    private let fileQueueManager = FileQueueManager()
    private var sendTimer: Timer?
    private let logDelegate = LZ4CompressionLogDelegate()
    
    init() {
        // 设置默认路径
        if let bundlePath = Bundle.main.bundlePath as NSString? {
            let projectPath = (bundlePath as NSString).deletingLastPathComponent
            folderPath = "\(projectPath)/2026012714"
        }
        
        // 默认输出目录为 Documents
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            outputDirectory = documentsPath.path
        }
    }
    
    // MARK: - SDK Actions
    
    func initializeSDK() {
        appendLog("正在初始化 SDK...")
        sdkStatus = "初始化中..."
        
        let options = EMOptions(appkey: appKey)
        options.enableConsoleLog = true
        options.isAutoLogin = false
        
        // 初始化 SDK
        EMClient.shared().initializeSDK(with: options)
        
        // 注册日志代理
        EMClient.shared.addLog(delegate: logDelegate, queue: nil)
        
        DispatchQueue.main.async {
            self.isSDKInitialized = true
            self.sdkStatus = "已初始化 (\(self.appKey))"
            self.appendLog("SDK 初始化成功")
        }
    }
    
    // MARK: - Account Actions
    
    func login() {
        guard isSDKInitialized else {
            appendLog("请先初始化 SDK")
            return
        }
        
        appendLog("正在登录...")
        loginStatus = "登录中..."
        
        EMClient.shared().login(withUsername: username, password: password) { [weak self] (aUsername, aError) in
            DispatchQueue.main.async {
                if let error = aError {
                    self?.loginStatus = "登录失败: \(error.errorDescription ?? "")"
                    self?.appendLog("登录失败: \(error.errorDescription ?? "")")
                    self?.isLoggedIn = false
                } else {
                    self?.loginStatus = "已登录: \(aUsername ?? "")"
                    self?.appendLog("登录成功: \(aUsername ?? "")")
                    self?.isLoggedIn = true
                }
            }
        }
    }
    
    func logout() {
        appendLog("正在退出...")
        EMClient.shared().logout(false) { [weak self] aError in
            DispatchQueue.main.async {
                if let error = aError {
                    self?.appendLog("退出失败: \(error.errorDescription ?? "")")
                } else {
                    self?.loginStatus = "未登录"
                    self?.appendLog("退出成功")
                    self?.isLoggedIn = false
                }
            }
        }
    }
    
    // MARK: - File Reading
    
    func prepareFiles() {
        appendLog("正在准备文件...")
        currentIndex = 0
        totalMessages = 0
        
        let result = fileQueueManager.prepare(folderPath: folderPath)
        
        if result.success {
            appendLog("文件准备完成，共 \(result.fileCount) 个文件")
            appendLog("流式读取模式：边读边发，不会占用大量内存")
        } else {
            appendLog("错误: \(result.error ?? "未知错误")")
        }
    }
    
    private func parseJsonLine(_ line: String) -> String? {
        guard let data = line.data(using: .utf8) else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let payload = json["payload"] as? [String: Any],
               let bodies = payload["bodies"] as? [[String: Any]],
               let firstBody = bodies.first {
                // 优先返回 action，如果没有则返回 msg
                if let action = firstBody["action"] as? String {
                    return action
                } else if let msg = firstBody["msg"] as? String {
                    return msg
                }
            }
        } catch {
            // 解析失败，跳过
        }
        return nil
    }
    
    // MARK: - Message Sending
    
    func sendSingleMessage() {
        guard isLoggedIn else {
            appendLog("请先登录")
            return
        }
        
        guard fileQueueManager.isReady else {
            appendLog("请先准备文件")
            return
        }
        
        // 读取下一行并发送
        if let line = fileQueueManager.readNextLine() {
            if let action = parseJsonLine(line) {
                sendCmdMessage(action: action)
                currentIndex += 1
                updateSendStatus()
            } else {
                appendLog("解析失败，跳过这一行")
                // 递归读取下一行
                sendSingleMessage()
            }
        } else {
            appendLog("所有消息已发送完毕")
        }
    }
    
    func startAutoSend() {
        guard isLoggedIn else {
            appendLog("请先登录")
            return
        }
        
        guard fileQueueManager.isReady else {
            appendLog("请先准备文件")
            return
        }
        
        isSending = true
        appendLog("开始自动发送，间隔 \(sendInterval) 毫秒")
        appendLog("流式模式：边读边发，内存占用极低")
        
        scheduleNextSend()
    }
    
    private func scheduleNextSend() {
        guard isSending else { return }
        
        let interval = Double(sendInterval) / 1000.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            guard let self = self, self.isSending else { return }
            
            // 读取下一行
            if let line = self.fileQueueManager.readNextLine() {
                if let action = self.parseJsonLine(line) {
                    self.sendCmdMessage(action: action)
                    self.currentIndex += 1
                    self.updateSendStatus()
                }
                // 继续调度下一次发送
                self.scheduleNextSend()
            } else {
                // 文件读取完毕
                self.isSending = false
                self.appendLog("所有消息发送完毕，共发送 \(self.currentIndex) 条")
            }
        }
    }
    
    func stopAutoSend() {
        isSending = false
        sendTimer?.invalidate()
        sendTimer = nil
        appendLog("已停止自动发送")
    }
    
    func resetSendIndex() {
        // 重置文件队列
        let result = fileQueueManager.prepare(folderPath: folderPath)
        currentIndex = 0
        totalMessages = 0
        updateSendStatus()
        if result.success {
            appendLog("已重置，可以重新发送")
        } else {
            appendLog("重置失败: \(result.error ?? "")")
        }
    }
    
    private func sendCmdMessage(action: String) {
        let cmdBody = EMCmdMessageBody(action: action)
        let msg = EMChatMessage(conversationID: targetUserId, body: cmdBody, ext: nil)
        msg.chatType = .chat
        
        EMClient.shared().chatManager?.send(msg, progress: nil) { [weak self] message, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.appendLog("发送失败: \(error.errorDescription ?? "")")
                } else {
                    // 发送成功，不打印日志避免刷屏
                }
            }
        }
    }
    
    private func updateSendStatus() {
        DispatchQueue.main.async {
            self.sendStatus = "\(self.currentIndex) / \(self.totalMessages)"
        }
    }
    
    // MARK: - Log Statistics
    
    /// 开始收集日志（在发送消息前调用）
    func startLogCollection() {
        let outputPath = "\(outputDirectory)/output.md"
        
        if LZ4LogCollector.shared.startCollecting(outputPath: outputPath) {
            appendLog("开始收集 LZ4 日志...")
            appendLog("日志将实时写入: \(outputPath)")
        } else {
            appendLog("错误: 无法创建输出文件")
        }
    }
    
    /// 停止收集并生成报告
    func stopLogCollection() {
        let result = LZ4LogCollector.shared.stopCollecting()
        
        if result.success {
            appendLog("日志收集完成！")
            appendLog("共收集 \(result.entryCount) 条 LZ4 压缩记录")
            appendLog("结果已保存到: \(result.outputPath)")
        } else {
            appendLog("日志收集未开始或已停止")
        }
    }
    
    // MARK: - Logging
    
    private func appendLog(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.logText += "[\(timestamp)] \(message)\n"
        }
    }
}

// MARK: - Main View

struct LZ4CompressionTestView: View {
    @StateObject private var viewModel = LZ4CompressionTestViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 账号配置区域
                accountSection
                
                Divider()
                
                // 文件配置区域
                fileSection
                
                Divider()
                
                // 日志统计区域
                statisticsSection
                
                Divider()
                
                // 发送控制区域
                sendSection
                
                Divider()
                
                // 日志输出
                logSection
            }
            .padding(.horizontal)
            // .padding(.top, 16)
            // .padding(.bottom, 40) // 底部额外间距
        }
        .padding(.vertical)
        .background(Color(UIColor.systemBackground)) // 添加背景色，防止内容透过
        // .ignoresSafeArea(.all)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("账号配置")
                .font(.headline)
            
            HStack {
                Text("AppKey:")
                    .frame(width: 80, alignment: .leading)
                TextField("AppKey", text: $viewModel.appKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Text("SDK状态:")
                    .frame(width: 80, alignment: .leading)
                Text(viewModel.sdkStatus)
                    .foregroundColor(viewModel.isSDKInitialized ? .green : .orange)
                    .font(.system(size: 12))
            }
            
            Button(action: { viewModel.initializeSDK() }) {
                Text("初始化 SDK")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(viewModel.isSDKInitialized ? Color.gray : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(viewModel.isSDKInitialized)
            
            HStack {
                Text("用户名:")
                    .frame(width: 80, alignment: .leading)
                TextField("用户名", text: $viewModel.username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
            }
            
            HStack {
                Text("密码:")
                    .frame(width: 80, alignment: .leading)
                SecureField("密码", text: $viewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Text("登录状态:")
                    .frame(width: 80, alignment: .leading)
                Text(viewModel.loginStatus)
                    .foregroundColor(viewModel.isLoggedIn ? .green : .gray)
                    .font(.system(size: 12))
            }
            
            HStack(spacing: 16) {
                Button(action: { viewModel.login() }) {
                    Text("登录")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.isSDKInitialized && !viewModel.isLoggedIn ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!viewModel.isSDKInitialized || viewModel.isLoggedIn)
                
                Button(action: { viewModel.logout() }) {
                    Text("退出")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.isLoggedIn ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!viewModel.isLoggedIn)
            }
        }
    }
    
    // MARK: - File Section
    
    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文件配置")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("文件夹路径:")
                HStack {
                    TextField("粘贴或选择文件夹路径", text: $viewModel.folderPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12))
                    FolderPickerButton(selectedPath: $viewModel.folderPath)
                }
            }
            
            HStack {
                Text("目标用户ID:")
                    .frame(width: 100, alignment: .leading)
                TextField("目标用户ID", text: $viewModel.targetUserId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
            }
            
            Button(action: { viewModel.prepareFiles() }) {
                Text("准备文件 (流式读取)")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Send Section
    
    private var sendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("发送控制")
                .font(.headline)
            
            HStack {
                Text("发送间隔(ms):")
                    .frame(width: 120, alignment: .leading)
                TextField("毫秒", value: $viewModel.sendInterval, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            
            HStack {
                Text("发送进度:")
                    .frame(width: 120, alignment: .leading)
                Text(viewModel.sendStatus.isEmpty ? "0 / 0" : viewModel.sendStatus)
                    .foregroundColor(.blue)
            }
            
            HStack(spacing: 12) {
                Button(action: { viewModel.sendSingleMessage() }) {
                    Text("手动发送")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: { viewModel.resetSendIndex() }) {
                    Text("重置")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { viewModel.startAutoSend() }) {
                    Text("开始自动发送")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.isSending ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(viewModel.isSending)
                
                Button(action: { viewModel.stopAutoSend() }) {
                    Text("停止发送")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(viewModel.isSending ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!viewModel.isSending)
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日志收集")
                .font(.headline)
            
            HStack {
                Text("收集状态:")
                    .frame(width: 100, alignment: .leading)
                Text(LZ4LogCollector.shared.collecting ? "收集中..." : "未开始")
                    .foregroundColor(LZ4LogCollector.shared.collecting ? .green : .gray)
            }
            
            HStack {
                Text("已收集:")
                    .frame(width: 100, alignment: .leading)
                Text("\(LZ4LogCollector.shared.count) 条 LZ4 日志")
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("输出目录:")
                HStack {
                    TextField("粘贴或选择输出目录", text: $viewModel.outputDirectory)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12))
                    FolderPickerButton(selectedPath: $viewModel.outputDirectory)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { viewModel.startLogCollection() }) {
                    Text("开始收集")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(LZ4LogCollector.shared.collecting ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(LZ4LogCollector.shared.collecting)
                
                Button(action: { viewModel.stopLogCollection() }) {
                    Text("停止并导出")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(LZ4LogCollector.shared.collecting ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!LZ4LogCollector.shared.collecting)
            }
            
            Text("提示: 先开始收集，再发送消息，最后停止并导出")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    
    // MARK: - Log Section
    
    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("运行日志")
                    .font(.headline)
                Spacer()
                Button("清空") {
                    viewModel.logText = ""
                }
                .font(.caption)
            }
            
            ScrollView {
                Text(viewModel.logText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Document Picker

/// 文件夹选择按钮 - 直接使用 UIKit 展示选择器，避免 SwiftUI .sheet 在模态层级中的问题
struct FolderPickerButton: View {
    @Binding var selectedPath: String
    var iconName: String = "folder"
    
    var body: some View {
        Button(action: {
            #if targetEnvironment(simulator)
            print("模拟器可以直接读取 Mac 上的绝对路径，非常方便调试")
            #else
            showDocumentPicker()
            #endif
        }) {
            Image(systemName: iconName)
                .foregroundColor(.blue)
                .padding(8)
                .background(Color(.systemGray5))
                .cornerRadius(6)
        }
    }
    
    private func showDocumentPicker() {
        DispatchQueue.main.async {
            // 创建文档选择器 - 只选择文件夹
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            picker.allowsMultipleSelection = false
            
            // 模拟器上使用 fullScreen 样式，避免顶部按钮被刘海遮挡
            #if targetEnvironment(simulator)
            picker.modalPresentationStyle = .fullScreen
            #endif
            
            // 创建代理处理器
            let delegate = DocumentPickerDelegate(selectedPath: self.$selectedPath)
            picker.delegate = delegate
            
            // 保持代理引用，防止被释放
            objc_setAssociatedObject(picker, "delegateKey", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            // 从当前最顶层的视图控制器展示
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                // 找到最顶层的 presented view controller
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(picker, animated: true)
            }
        }
    }
}

/// 文档选择器代理
class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private var selectedPath: Binding<String>
    
    init(selectedPath: Binding<String>) {
        self.selectedPath = selectedPath
        super.init()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // 开始访问安全作用域资源
        let accessing = url.startAccessingSecurityScopedResource()
        
        // 获取路径
        let path = url.path
        
        // 停止访问（如果需要持续访问文件，应该在使用完后再停止）
        if accessing {
            // 注意：如果需要持续访问这个路径下的文件，不应该立即停止访问
            // 这里我们只是获取路径，所以可以停止
            url.stopAccessingSecurityScopedResource()
        }
        
        // 更新路径
        DispatchQueue.main.async {
            self.selectedPath.wrappedValue = path
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // 用户取消，不需要处理
    }
}

// MARK: - Document Picker

// /// 文件夹选择按钮 - 优化模拟器交互稳定性
// struct FolderPickerButton: View {
//     @Binding var selectedPath: String
//     var iconName: String = "folder"
    
//     var body: some View {
//         Button(action: {
//             #if targetEnvironment(simulator)
//             // 模拟器不使用文件选择器

//             #else
//             showDocumentPicker()
//             #endif
//         }) {
//             Image(systemName: iconName)
//                 .foregroundColor(.blue)
//                 .padding(8)
//                 .background(Color(.systemGray5))
//                 .cornerRadius(6)
//         }
//     }
    
//     private func showDocumentPicker() {
//         DispatchQueue.main.async {
//             // 1. 获取最顶层的 ViewController
//             guard let topVC = self.getTopViewController() else {
//                 print("Error: Could not find top view controller")
//                 return
//             }

//             // 2. 创建文档选择器
//             let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
//             picker.allowsMultipleSelection = false
            
//             // 3. 关键修复：针对模拟器强制全屏展示
//             // 在模拟器中，默认的 .pageSheet 经常导致层级无法响应点击，全屏模式能强制刷新渲染进程
//             #if targetEnvironment(simulator)
//             picker.modalPresentationStyle = .fullScreen
//             #else
//             picker.modalPresentationStyle = .automatic
//             #endif
            
//             // 4. 设置代理并确保其生命周期
//             let delegate = DocumentPickerDelegate(selectedPath: self.$selectedPath)
//             picker.delegate = delegate
//             objc_setAssociatedObject(picker, "delegateKey", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
//             // 5. 执行展示
//             topVC.present(picker, animated: true)
//         }
//     }
    
//     /// 递归查找当前视图树中最顶层的 ViewController
//     private func getTopViewController() -> UIViewController? {
//         guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//               let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
//             return nil
//         }
//         return findTopVC(from: rootVC)
//     }
    
//     private func findTopVC(from vc: UIViewController) -> UIViewController {
//         if let presented = vc.presentedViewController {
//             return findTopVC(from: presented)
//         }
//         if let nav = vc as? UINavigationController {
//             return findTopVC(from: nav.visibleViewController ?? nav)
//         }
//         if let tab = vc as? UITabBarController {
//             return findTopVC(from: tab.selectedViewController ?? tab)
//         }
//         return vc
//     }
// }

// /// 文档选择器代理
// class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
//     private var selectedPath: Binding<String>
    
//     init(selectedPath: Binding<String>) {
//         self.selectedPath = selectedPath
//         super.init()
//     }
    
//     func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
//         guard let url = urls.first else { return }
        
//         // 确保获取安全权限（虽然选择目录后通常由系统授予，但显式调用更稳健）
//         let canAccess = url.startAccessingSecurityScopedResource()
//         let path = url.path
        
//         DispatchQueue.main.async {
//             self.selectedPath.wrappedValue = path
//             // 如果后续需要读写，请根据需要决定何时调用 stopAccessingSecurityScopedResource()
//             if canAccess {
//                 url.stopAccessingSecurityScopedResource()
//             }
//         }
//     }
    
//     func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
//         // 用户取消时确保解除模态
//         controller.dismiss(animated: true)
//     }
// }

// MARK: - Preview

struct LZ4CompressionTestView_Previews: PreviewProvider {
    static var previews: some View {
        LZ4CompressionTestView()
    }
}
