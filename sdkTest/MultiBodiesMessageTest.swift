import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
@preconcurrency import HyphenateChat

/// 单个及多个消息体的独立手动测试页，沿用 MediaFilePickerTest 的系统选择器。
struct MultiBodiesMessageTest: View {
    @StateObject private var model = MultiBodiesMessageModel()
    @ObservedObject private var session = SDKLoginState.shared
    @State private var showLogin = false
    @State private var text = ""
    @State private var paths = ""
    @State private var showFiles = false
    @State private var imageFiles = false
    @State private var showPhotos = false
    @State private var photos: [PhotosPickerItem] = []

    var body: some View {
        Form {
            Section("SDK 与登录") {
                Text("SDK：\(session.initialized ? "已初始化" : "未初始化")　账号：\(session.loggedIn ? session.username : "未登录")")
                Text("连接：\(session.connected ? "已连接" : "未连接")")
                Button("打开登录与初始化页面") { showLogin = true }
            }
            Section("发送目标") {
                TextField("用户 / 群组 / 聊天室 ID", text: $model.target)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("会话类型", selection: $model.chatType) {
                    Text("单聊").tag(0)
                    Text("群聊").tag(1)
                    Text("聊天室").tag(2)
                }
                Text("群聊和聊天室请使用当前账号已加入的目标。")
                    .font(.caption).foregroundStyle(.secondary)
            }.disabled(model.busy)
            Section("自由添加消息体") {
                TextField("输入一段文本，可多次添加", text: $text, axis: .vertical)
                Button("添加文本") {
                    guard !text.isEmpty else { return }
                    model.drafts.append(.init(kind: .text, value: text, name: "文本"))
                    text = ""
                }
                HStack {
                    Button("选择多张照片") { showPhotos = true }
                    Button("选择图片文件") { imageFiles = true; showFiles = true }
                    Button("选择多个文件") { imageFiles = false; showFiles = true }
                }.buttonStyle(.bordered)
                TextField("也可粘贴本地路径，每行一个", text: $paths, axis: .vertical)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                HStack {
                    Button("按文件添加路径") { addPaths(images: false) }
                    Button("按图片添加路径") { addPaths(images: true) }
                }.buttonStyle(.bordered)
                Text("文件必须可由当前设备访问；真机请优先使用选择器。选择后不会立即发送。")
                    .font(.caption).foregroundStyle(.secondary)
            }.disabled(model.busy)
            Section("发送顺序 · \(model.drafts.count) 个 bodies") {
                ForEach(Array(model.drafts.enumerated()), id: \.element.id) { index, draft in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("[\(index)] \(draft.kind.rawValue) · \(draft.name)").font(.headline)
                        Text(draft.value).font(.caption).textSelection(.enabled)
                        if draft.kind != .text { Text("\(draft.bytes) bytes").font(.caption) }
                        HStack {
                            Button("上移") { model.move(index, by: -1) }.disabled(index == 0)
                            Button("下移") { model.move(index, by: 1) }.disabled(index + 1 == model.drafts.count)
                            Button("删除", role: .destructive) { model.drafts.remove(at: index) }
                        }.buttonStyle(.bordered)
                    }
                }
                Toggle("单 body 使用原发送 API", isOn: $model.legacySingle)
                Text("仅一个 body 时可验证旧 API；多个 body 作为一条复合消息发送，顺序以上方列表为准。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.busy ? "处理中…" : "发送这条消息") { model.send() }
                        .disabled(!session.loggedIn || session.busy || model.drafts.isEmpty || model.target.isEmpty)
                    Button("清空列表", role: .destructive) { model.drafts.removeAll() }
                }.buttonStyle(.borderedProminent)
            }.disabled(model.busy)
            Section("收到 / 已发送的消息") {
                ForEach(Array(model.messages.enumerated()), id: \.offset) { _, message in
                    Button("\(message.messageId) · \(message.bodies.count) bodies") {
                        model.select(message)
                    }
                }
                TextField("消息 ID（保留最近 ID，可重启后读取）", text: $model.messageId)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                HStack {
                    Button("从本地读取") { model.load() }
                    Button("保存当前消息") { model.save() }
                        .disabled(model.selected == nil)
                }.buttonStyle(.bordered).disabled(!session.loggedIn || session.busy || model.busy)
                if let message = model.selected {
                    Text("\(message.bodies.count > 1 ? "复合消息" : "单 body 消息") · \(message.messageId)")
                    Text(model.describe(message)).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Picker("下载资源", selection: $model.downloadResource) {
                        Text("原附件").tag(0)
                        Text("缩略图").tag(1)
                        Text("大图").tag(2)
                    }
                    Picker("下载范围", selection: $model.downloadIndex) {
                        Text("整条消息").tag(-1)
                        ForEach(message.bodies.indices, id: \.self) { index in
                            Text("body[\(index)]").tag(index)
                        }
                    }
                    Button("下载 / 重试所选附件") { model.download() }
                        .disabled(!session.loggedIn || session.busy || model.busy)
                }
            }
            Section("进度与结果") {
                Button("清空日志") { model.logs.removeAll() }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(model.logs.enumerated()), id: \.offset) { _, log in
                            Text(log).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 240)
            }
        }
        .navigationTitle("多 bodies 消息")
        .onAppear { session.refresh(); model.activate() }
        .onDisappear { model.deactivate() }
        .onChange(of: session.initialized) { _, initialized in
            if initialized { model.activate() }
        }
        .sheet(isPresented: $showLogin, onDismiss: { session.refresh(); model.activate() }) {
            NavigationStack {
                SDKLoginView().toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("返回测试") { showLogin = false } }
                }
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: imageFiles ? [.image] : [.item],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): model.importFiles(urls, images: imageFiles)
            case .failure(let error): model.log("选择失败：\(error.localizedDescription)")
            }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photos,
                      selectionBehavior: .ordered, matching: .images)
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            model.importPhotos(items)
            photos = []
        }
    }

    private func addPaths(images: Bool) {
        let urls = paths.split(whereSeparator: \.isNewline).map {
            URL(fileURLWithPath: String($0).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard !urls.isEmpty else { return }
        model.importFiles(urls, images: images)
        paths = ""
    }
}

private struct MultiBodiesDraft: Identifiable {
    enum Kind: String { case text = "TEXT", image = "IMAGE", file = "FILE" }
    let id = UUID()
    let kind: Kind
    let value: String
    let name: String
    var bytes: Int64 = 0
}

@MainActor
private final class MultiBodiesMessageModel: NSObject, ObservableObject, @preconcurrency EMChatManagerDelegate {
    @Published var drafts: [MultiBodiesDraft] = []
    @Published var logs: [String] = []
    @Published var messages: [EMChatMessage] = []
    @Published var selected: EMChatMessage?
    @Published var target = ""
    @Published var chatType = 0
    @Published var legacySingle = true
    @Published var busy = false
    @Published var downloadResource = 0
    @Published var downloadIndex = -1
    @Published var messageId = UserDefaults.standard.string(forKey: "multiBodies.lastMessageId") ?? ""

    func log(_ text: String) {
        NSLog("[MultiBodies] %@", text)
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("\(time) \(text)")
        if logs.count > 500 { logs.removeFirst(logs.count - 500) }
    }

    func activate() {
        EMClient.shared().chatManager?.remove(self)
        EMClient.shared().chatManager?.add(self, delegateQueue: .main)
    }

    func deactivate() { EMClient.shared().chatManager?.remove(self) }

    func move(_ index: Int, by offset: Int) {
        guard drafts.indices.contains(index + offset) else { return }
        drafts.swapAt(index, index + offset)
    }

    func importFiles(_ urls: [URL], images: Bool) {
        guard !busy else { return }
        busy = true
        // Copy while security-scoped access is held. SDK uploads continue after the picker closes.
        Task { @MainActor in
            let result = await Task.detached { () -> ([MultiBodiesDraft], [String]) in
                var imported: [MultiBodiesDraft] = []
                var failures: [String] = []
                for url in urls {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let info = try url.resourceValues(forKeys: [.isRegularFileKey])
                        guard info.isRegularFile == true else {
                            failures.append("\(url.lastPathComponent)：请选择文件"); continue
                        }
                        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("MultiBodiesImports/\(UUID().uuidString)", isDirectory: true)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let local = directory.appendingPathComponent(url.lastPathComponent)
                        try FileManager.default.copyItem(at: url, to: local)
                        let attributes = try FileManager.default.attributesOfItem(atPath: local.path)
                        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                        imported.append(.init(kind: images ? .image : .file, value: local.path,
                                              name: url.lastPathComponent, bytes: bytes))
                    } catch { failures.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
                }
                return (imported, failures)
            }.value
            drafts.append(contentsOf: result.0)
            result.1.forEach { log("导入失败：\($0)") }
            log("已添加 \(result.0.count) 个\(images ? "图片" : "文件") body，顺序可在列表中调整")
            busy = false
        }
    }

    func importPhotos(_ items: [PhotosPickerItem]) {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            // Await each selection in order; completion timing must not reorder bodies.
            for item in items {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        log("照片导入失败：没有可读取数据"); continue
                    }
                    let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("MultiBodiesImports", isDirectory: true)
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    let local = url.appendingPathComponent("\(UUID().uuidString).\(ext)")
                    try data.write(to: local, options: .atomic)
                    drafts.append(.init(kind: .image, value: local.path, name: local.lastPathComponent,
                                        bytes: Int64(data.count)))
                } catch { log("照片导入失败：\(error.localizedDescription)") }
            }
            busy = false
            log("照片添加完成，共 \(drafts.count) 个 bodies")
        }
    }

    func send() {
        guard let manager = EMClient.shared().chatManager, !busy, !drafts.isEmpty else { return }
        let receiver = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !receiver.isEmpty else { log("请填写接收目标"); return }
        let bodies: [EMMessageBody] = drafts.map { draft in
            switch draft.kind {
            case .text: return EMTextMessageBody(text: draft.value)
            case .image:
                if URL(fileURLWithPath: draft.value).pathExtension.lowercased() == "gif" {
                    return EMImageMessageBody(gifFilePath: draft.value, displayName: draft.name)
                }
                return EMImageMessageBody(localPath: draft.value, displayName: draft.name)
            case .file: return EMFileMessageBody(localPath: draft.value, displayName: draft.name)
            }
        }
        let legacy = legacySingle && bodies.count == 1
        let message: EMChatMessage?
        if legacy {
            message = EMChatMessage(conversationID: receiver, body: bodies[0], ext: nil)
        } else {
            message = EMChatMessage(conversationID: receiver, bodies: bodies, ext: nil)
        }
        guard let message else { log("消息构造失败，检查 bodies"); return }
        message.chatType = EMChatType(rawValue: chatType) ?? .chat
        busy = true
        select(message)
        log("发送 \(legacy ? "旧 API 单 body" : "新 API")，bodyCount=\(bodies.count)\n\(describe(message))")
        let completion: @Sendable (EMChatMessage?, EMError?) -> Void = { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                self.remember(result ?? message)
                self.log(error.map { "发送失败 [\($0.code.rawValue)]：\($0.errorDescription ?? "")" }
                         ?? "发送成功 messageId=\((result ?? message).messageId)")
            }
        }
        if legacy {
            manager.send(message, progress: { [weak self] percent in
                self?.log("上传 body[0] \(percent)%")
            }, completion: completion)
        } else {
            manager.send(message, bodyProgress: { [weak self] percent, index in
                self?.log("上传 body[\(index)] \(percent)%")
            }, completion: completion)
        }
    }

    func select(_ message: EMChatMessage) {
        selected = message
        messageId = message.messageId
        downloadIndex = -1
        UserDefaults.standard.set(messageId, forKey: "multiBodies.lastMessageId")
    }

    private func remember(_ message: EMChatMessage) {
        messages.removeAll { $0.messageId == message.messageId }
        messages.insert(message, at: 0)
        if messages.count > 30 { messages.removeLast() }
        select(message)
    }

    func load() {
        let id = messageId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let message = EMClient.shared().chatManager?.getMessageWithMessageId(id) else {
            log("本地未找到消息：\(id)"); return
        }
        remember(message)
        log("本地读取：\n\(describe(message))")
    }

    func save() {
        guard let message = selected,
              let conversation = EMClient.shared().chatManager?.getConversation(message.conversationId,
                    type: EMConversationType(rawValue: message.chatType.rawValue) ?? .chat,
                    createIfNotExist: true) else { return }
        var error: EMError?
        conversation.insert(message, error: &error)
        log("保存 \(message.messageId)：\(error.map { "失败 \($0.errorDescription ?? "")" } ?? "成功")")
    }

    func download() {
        guard let message = selected, let manager = EMClient.shared().chatManager, !busy else { return }
        busy = true
        let index = downloadIndex
        let resource = downloadResource
        log("开始下载 \(message.messageId)，\(index < 0 ? "全部 bodies" : "body[\(index)]")，资源=\(resource)")
        let progress: (Int32, Int32) -> Void = { [weak self] percent, bodyIndex in
            self?.log("下载 body[\(bodyIndex)] \(percent)%")
        }
        let bodyCompletion: (EMChatMessage?, Int32, EMError?) -> Void = { [weak self] _, bodyIndex, error in
            self?.log("下载 body[\(bodyIndex)]：\(error.map { "失败 \($0.code.rawValue) \($0.errorDescription ?? "")" } ?? "成功")")
        }
        let completion: @Sendable (EMChatMessage?, EMError?) -> Void = { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                self.selected = result ?? message
                self.log("下载请求结束：\(error.map { "失败 \($0.code.rawValue) \($0.errorDescription ?? "")" } ?? "成功")")
            }
        }
        if index >= 0 {
            let singleProgress: (Int32) -> Void = { progress($0, Int32(index)) }
            switch resource {
            case 1: manager.downloadMessageThumbnail(message, bodyIndex: UInt(index), progress: singleProgress, completion: completion)
            case 2: manager.downloadBigImageAttachment(message, bodyIndex: UInt(index), progress: singleProgress, completion: completion)
            default: manager.downloadMessageAttachment(message, bodyIndex: UInt(index), progress: singleProgress, completion: completion)
            }
        } else {
            switch resource {
            case 1: manager.downloadMessageThumbnail(message, bodyProgress: progress, bodyCompletion: bodyCompletion, completion: completion)
            case 2: manager.downloadBigImageAttachment(message, bodyProgress: progress, bodyCompletion: bodyCompletion, completion: completion)
            default: manager.downloadMessageAttachment(message, bodyProgress: progress, bodyCompletion: bodyCompletion, completion: completion)
            }
        }
    }

    func describe(_ message: EMChatMessage) -> String {
        message.bodies.enumerated().map { index, body in
            if let text = body as? EMTextMessageBody { return "[\(index)] TEXT \(text.text)" }
            if let file = body as? EMFileMessageBody {
                var line = "[\(index)] type=\(body.type.rawValue) \(file.displayName ?? "") bytes=\(file.fileLength) status=\(file.downloadStatus.rawValue)\n\(file.localPath ?? "")"
                if let image = body as? EMImageMessageBody {
                    line += "\nthumbnail=\(image.thumbnailDownloadStatus.rawValue) big=\(image.bigImageDownloadStatus.rawValue)"
                }
                return line
            }
            return "[\(index)] type=\(body.type.rawValue)"
        }.joined(separator: "\n")
    }

    func messagesDidReceive(_ aMessages: [EMChatMessage]) {
        for message in aMessages {
            remember(message)
            log("收到消息 \(message.messageId)：\n\(describe(message))")
        }
    }

    func messageAttachmentStatusDidChange(_ aMessage: EMChatMessage, error aError: EMError?) {
        if selected?.messageId == aMessage.messageId { selected = aMessage }
        log("附件 listener \(aMessage.messageId) error=\(aError?.code.rawValue ?? 0)\n\(describe(aMessage))")
    }
}
