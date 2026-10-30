import SwiftUI
@preconcurrency import HyphenateChat

/// 新页面共用的登录与初始化入口；已有测试页继续保持原实现。
struct SDKLoginView: View {
    @ObservedObject private var session = SDKLoginState.shared
    @ObservedObject private var token = SDKLoginState.shared.token

    var body: some View {
        Form {
            Section("共享 SDK 状态") {
                Text("初始化：\(session.initialized ? "已完成" : "未完成")")
                Text("登录：\(session.loggedIn ? session.username : "未登录")")
                Text("连接：\(session.connected ? "已连接" : "未连接")")
                Button("刷新状态") { session.refresh() }
            }
            EasemobUserTokenForm(viewModel: token, isAppKeyLocked: session.initialized)
                .disabled(session.busy)
            Section("可选初始化参数") {
                DisclosureGroup("展开配置（未设置时使用 SDK 默认值）") {
                    option("控制台日志", selection: $session.consoleLog)
                    option("仅使用 HTTPS", selection: $session.httpsOnly)
                    option("自动传输消息附件", selection: $session.transferAttachments)
                    option("自动下载缩略图和语音", selection: $session.autoDownload)
                    option("同步联系人", selection: $session.syncContacts)
                }
                .disabled(session.initialized || session.busy)
                Text("“默认”不会覆盖 SDK 参数。会话列表登录成功后总会自动同步；同步联系人对齐 EMOptions.dataSyncType 位掩码。初始化配置在进程中只生效一次，修改已生效的初始化参数请重启 App。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("操作") {
                Button("初始化 SDK") { session.initialize() }
                    .disabled(session.initialized || session.busy)
                Button(session.busy ? "处理中…" : "登录") { session.login() }
                    .disabled(!session.initialized || session.loggedIn || session.busy || token.isLoading)
                Button("退出登录", role: .destructive) { session.logout() }
                    .disabled(!session.loggedIn || session.busy)
                Text("多 bodies 页面共享此处的登录状态，无需重复初始化或登录。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("登录与接收日志") {
                Button("清空日志") { session.logs.removeAll() }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(session.logs.enumerated()), id: \.offset) { _, text in
                            Text(text).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 240)
                Text("登录后持续监听接收消息；切换页面仍会记录。日志同时输出到 Xcode 控制台。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("登录与初始化")
        .onAppear { session.refresh() }
    }

    private func option(_ title: String, selection: Binding<SDKLoginOption>) -> some View {
        Picker(title, selection: selection) {
            ForEach(SDKLoginOption.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
    }
}

enum SDKLoginOption: String, CaseIterable {
    case sdkDefault = "默认"
    case enabled = "启用"
    case disabled = "禁用"

    var value: Bool? {
        switch self {
        case .sdkDefault: return nil
        case .enabled: return true
        case .disabled: return false
        }
    }
}

/// 仅保存当前进程的状态及输入，不持久化密码或 Token。
@MainActor
final class SDKLoginState: NSObject, ObservableObject, @preconcurrency EMClientDelegate, @preconcurrency EMChatManagerDelegate {
    static let shared = SDKLoginState()
    let token = EasemobUserTokenViewModel()
    @Published private(set) var initialized = false
    @Published private(set) var loggedIn = false
    @Published private(set) var connected = false
    @Published private(set) var username = ""
    @Published private(set) var busy = false
    @Published var logs: [String] = []
    @Published var consoleLog = SDKLoginOption.enabled
    @Published var httpsOnly = SDKLoginOption.sdkDefault
    @Published var transferAttachments = SDKLoginOption.sdkDefault
    @Published var autoDownload = SDKLoginOption.sdkDefault
    @Published var syncContacts = SDKLoginOption.enabled
    private var listening = false

    private override init() { super.init() }

    func refresh() {
        // The public manager accessor returns nil until initialization succeeds.
        initialized = EMClient.shared().chatManager != nil
        loggedIn = EMClient.shared().isLoggedIn
        connected = EMClient.shared().isConnected
        username = EMClient.shared().currentUsername ?? ""
        if initialized {
            token.appKey = EMClient.shared().options.appkey
            if !listening {
                EMClient.shared().add(self, delegateQueue: .main)
                EMClient.shared().chatManager?.add(self, delegateQueue: .main)
                listening = true
                log("已注册消息接收与附件状态监听")
            }
        }
    }

    func initialize() {
        refresh()
        guard !initialized else { log("复用当前进程中已初始化的 SDK"); return }
        let appKey = token.appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = EMOptions(appkey: appKey)
        if let value = consoleLog.value { options.enableConsoleLog = value }
        if let value = httpsOnly.value { options.usingHttpsOnly = value }
        if let value = transferAttachments.value { options.isAutoTransferMessageAttachments = value }
        if let value = autoDownload.value { options.autoDownloadThumbnail = value }
        if syncContacts != .sdkDefault {
            var sync: EMDataSyncType = []
            if syncContacts.value ?? false { sync.insert(.contacts) }
            options.dataSyncType = sync
        }
        if let error = EMClient.shared().initializeSDK(with: options) {
            log("初始化失败 [\(error.code.rawValue)]：\(error.errorDescription ?? "")")
            return
        }
        refresh()
        log("初始化完成：\(appKey)，console=\(options.enableConsoleLog)，HTTPS=\(options.usingHttpsOnly)，transfer=\(options.isAutoTransferMessageAttachments)，autoDownload=\(options.autoDownloadThumbnail)，sync=\(describeDataSyncType(options.dataSyncType))")
    }

    func login() {
        guard initialized, !busy else { return }
        let name = token.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { log("请填写用户名"); return }
        busy = true
        log("开始登录：\(name)")
        Task { @MainActor in
            defer { busy = false; refresh() }
            do {
                let value = try await token.resolveAccessToken()
                let (_, error) = await EMClient.shared().login(withUsername: name, token: value)
                log(error.map { "登录失败 [\($0.code.rawValue)]：\($0.errorDescription ?? "")" }
                    ?? "登录成功：\(name)")
            } catch { log("登录失败：\(error.localizedDescription)") }
        }
    }

    func logout() {
        guard !busy else { return }
        busy = true
        log("开始退出登录：\(username)")
        EMClient.shared().logout(false) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.busy = false
                self.refresh()
                self.log(error.map { "退出失败：\($0.errorDescription ?? "")" } ?? "已退出登录")
            }
        }
    }

    func connectionStateDidChange(_ aConnectionState: EMConnectionState) {
        refresh()
        log("连接状态：\(connected ? "已连接" : "未连接")")
    }

    func tokenDidExpire(_ aErrorCode: EMErrorCode) {
        refresh()
        log("Token 已过期，请在登录页更新 Token，错误码：\(aErrorCode.rawValue)")
    }

    func messagesDidReceive(_ aMessages: [EMChatMessage]) {
        for message in aMessages {
            logMessage(message, event: "收到消息")
        }
    }

    func messageAttachmentStatusDidChange(_ aMessage: EMChatMessage, error aError: EMError?) {
        let result = aError.map { "error=\($0.code.rawValue) \($0.errorDescription ?? "")" } ?? "error=0"
        logMessage(aMessage, event: "附件状态变化 \(result)")
    }

    private func logMessage(_ message: EMChatMessage, event: String) {
        log("\(event) messageId=\(message.messageId) from=\(message.from) to=\(message.to) conversationId=\(message.conversationId) direction=\(message.direction.rawValue) bodyCount=\(message.bodies.count)")
        for (index, body) in message.bodies.enumerated() {
            var detail = "messageId=\(message.messageId) body[\(index)] type=\(body.type.rawValue)"
            if let text = body as? EMTextMessageBody {
                detail += " TEXT=\(text.text)"
            } else if let file = body as? EMFileMessageBody {
                detail += " name=\(file.displayName ?? "") bytes=\(file.fileLength) downloadStatus=\(file.downloadStatus.rawValue) localPath=\(file.localPath ?? "")"
                if let image = body as? EMImageMessageBody {
                    detail += " thumbnailStatus=\(image.thumbnailDownloadStatus.rawValue) bigImageStatus=\(image.bigImageDownloadStatus.rawValue)"
                }
            }
            log(detail)
        }
    }

    private func describeDataSyncType(_ type: EMDataSyncType) -> String {
        var parts: [String] = []
        if type.contains(.conversations) { parts.append("会话") }
        if type.contains(.contacts) { parts.append("联系人") }
        return parts.isEmpty ? "无" : parts.joined(separator: "+")
    }

    private func log(_ text: String) {
        consoleLogChunked("[SDKDemo]", text)
        logs.append("\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) \(text)")
        if logs.count > 100 { logs.removeFirst(logs.count - 100) }
    }
}

/// NSLog 单条消息有长度上限（约 1KB），超长文本按 UTF-8 字节安全分片输出，分片带 [序号/总数] 前缀。
func consoleLogChunked(_ tag: String, _ text: String) {
    let maxBytes = 900
    guard text.utf8.count > maxBytes else {
        NSLog("%@ %@", tag, text)
        return
    }
    var chunks: [String] = []
    var chunk = ""
    var chunkBytes = 0
    for scalar in text.unicodeScalars {
        let scalarBytes = String(scalar).utf8.count
        if chunkBytes + scalarBytes > maxBytes {
            chunks.append(chunk)
            chunk = ""
            chunkBytes = 0
        }
        chunk.unicodeScalars.append(scalar)
        chunkBytes += scalarBytes
    }
    if !chunk.isEmpty { chunks.append(chunk) }
    for (index, part) in chunks.enumerated() {
        NSLog("%@ [%d/%d] %@", tag, index + 1, chunks.count, part)
    }
}
