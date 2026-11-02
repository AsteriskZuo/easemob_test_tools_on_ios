//
//  EnvLoginTestViewController.swift
//  sdkTest
//
//  Migrated from the standalone sdkTest project's ViewController.swift.
//  Independent test page: environment config + reflection password login.
//

import UIKit
import HyphenateChat
import Network

class EnvLoginTestViewController: UIViewController, UINavigationControllerDelegate {

    enum Env {
        case production
        case dev
        case tke
        case qa
    }

    private let env: Env = .tke
    //let Appkey = "sandbox-dee1#wdtest"
    //let Appkey = "easemob#easeim"
    //let Appkey = "52117440#955012"
    //let Appkey = "81446724#514456"
    //let Appkey = "easemob-demo#testngi02"//ngi
    private var Appkey: String { env == .tke ? "easemob#dutest" : "easemob-demo#support" }
    private let useAppId = false

    // MARK: - UI (originally Main.storyboard outlets)

    private let userIdField = UITextField()
    private let pwdField = UITextField()
    private let conversationIdField = UITextField()
    private let textField = UITextField()
    private let logView = UITextView()

    var messageId: String? = "1393146528809355220"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupViews()
        initView()
        initSDK()
    }

    // MARK: - Layout (mirrors the removed Main.storyboard)

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 35).isActive = true
        return button
    }

    private func setupViews() {
        let guide = view.safeAreaLayoutGuide

        let fields: [(UITextField, String)] = [
            (userIdField, "UserId"),
            (pwdField, "Password"),
            (conversationIdField, "ConversationId"),
            (textField, "Text"),
        ]
        for (field, placeholder) in fields {
            field.placeholder = placeholder
            field.borderStyle = .roundedRect
            field.font = .systemFont(ofSize: 14)
            field.translatesAutoresizingMaskIntoConstraints = false
            field.heightAnchor.constraint(equalToConstant: 30).isActive = true
            view.addSubview(field)
        }

        let loginButton = makeButton("Login", action: #selector(loginAction(_:)))
        let logoutButton = makeButton("Logout", action: #selector(logoutAction(_:)))
        let sendButton = makeButton("Send", action: #selector(sendAction(_:)))
        let fileButton = makeButton("File", action: #selector(sendFileAction(_:)))
        let recallButton = makeButton("Recall", action: #selector(recallAction(_:)))
        let modifyButton = makeButton("Modify", action: #selector(modifyAction(_:)))
        let testButton = makeButton("Test", action: #selector(testAction(_:)))
        for button in [loginButton, logoutButton, sendButton, fileButton, recallButton, modifyButton, testButton] {
            view.addSubview(button)
        }

        logView.isEditable = false
        logView.font = .systemFont(ofSize: 14)
        logView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logView)

        NSLayoutConstraint.activate([
            userIdField.topAnchor.constraint(equalTo: guide.topAnchor, constant: 30),
            userIdField.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 30),
            guide.trailingAnchor.constraint(equalTo: userIdField.trailingAnchor, constant: 30),

            pwdField.topAnchor.constraint(equalTo: userIdField.bottomAnchor, constant: 30),
            pwdField.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 30),
            guide.trailingAnchor.constraint(equalTo: pwdField.trailingAnchor, constant: 30),

            loginButton.topAnchor.constraint(equalTo: pwdField.bottomAnchor, constant: 30),
            loginButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 30),
            logoutButton.topAnchor.constraint(equalTo: pwdField.bottomAnchor, constant: 30),
            guide.trailingAnchor.constraint(equalTo: logoutButton.trailingAnchor, constant: 30),

            conversationIdField.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 30),
            conversationIdField.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 30),
            guide.trailingAnchor.constraint(equalTo: conversationIdField.trailingAnchor, constant: 30),

            textField.topAnchor.constraint(equalTo: conversationIdField.bottomAnchor, constant: 30),
            textField.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 30),
            guide.trailingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 30),

            sendButton.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 30),
            sendButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 30),
            fileButton.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 30),
            fileButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recallButton.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 30),
            guide.trailingAnchor.constraint(equalTo: recallButton.trailingAnchor, constant: 30),

            modifyButton.topAnchor.constraint(equalTo: sendButton.bottomAnchor, constant: 10),
            modifyButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 30),
            testButton.topAnchor.constraint(equalTo: sendButton.bottomAnchor, constant: 10),
            guide.trailingAnchor.constraint(equalTo: testButton.trailingAnchor, constant: 30),

            logView.topAnchor.constraint(equalTo: modifyButton.bottomAnchor, constant: 30),
            logView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 30),
            guide.trailingAnchor.constraint(equalTo: logView.trailingAnchor, constant: 30),
            guide.bottomAnchor.constraint(equalTo: logView.bottomAnchor, constant: 60),
        ])
    }

    public func initView() {
        self.pwdField.text = "1"
        self.userIdField.text = "lxm"
        self.conversationIdField.text = "374113988771844096"
        self.textField.text = "hello world"
    }

    func outputUnreadMessageCount(_ prefix: String) {
    }

    func loginWithPwd() {
        if let userId = userIdField.text,
           let pwd = pwdField.text {
            let ret = EMClient.shared()
                .perform(NSSelectorFromString("loginWithUsername:password:"), with: userId, with: pwd)?
                .takeUnretainedValue() as? EMError
            if let error = ret {
                self.printLog("login error: \(error.errorDescription ?? "")")
            } else {
                self.printLog("login success")
            }
        }
    }

    @objc func loginAction(_ sender: Any) {
//        loginWith007Token()
        loginWithPwd()
    }

    @objc func logoutAction(_ sender: Any) {
        logout()
    }

    func logout() {
        EMClient.shared().logout(false) { [weak self] aError in
            if let error = aError {
                EMClient.shared().logout(false)
                self?.printLog("logout error: \(error)")
            } else {
                self?.printLog("logout success")
            }
        }
    }

    @objc func sendAction(_ sender: Any) {
        if let text = self.textField.text {
            let body = EMTextMessageBody(text: text)
            let conversationId = self.conversationIdField.text
            for _ in 0...0 {
                let msg = EMChatMessage(conversationID: "\(conversationId ?? "")", body: body, ext: nil)
                EMClient.shared().chatManager?.send(msg, progress: nil, completion: { msg, err in
                    if err == nil {
                        self.messageId = msg?.messageId ?? ""
                    } else {
                        self.printLog("send message err")
                    }
                })
            }
        }
    }

    @objc func sendFileAction(_ sender: Any) {
        if let imageFile = Bundle.main.path(forResource: "1790589991070", ofType: "amr") {
            let imageBody = EMVoiceMessageBody(localPath: imageFile, displayName: "1790589991070.amr")
            imageBody.duration = 4
            let msg = EMChatMessage(conversationID: self.conversationIdField.text ?? "", body: imageBody, ext: nil)
            EMClient.shared().chatManager?.send(msg, progress: nil, completion: { msg, e in
                print("send file message result:\(e?.errorDescription ?? "success")")
            })
        }
    }

    @objc func recallAction(_ sender: Any) {
        recallMessage()
    }

    @objc func modifyAction(_ sender: Any) {
        modifyMessage()
    }

    func testPageLoadMessages(cursor: String?) {
        EMClient.shared().chatManager?.loadMessages(fromConversation: self.conversationIdField.text ?? "", cursor: cursor, pageSize: 20) { messages, e in
            if let list = messages?.list {
                for message in list {
                    print("messageId:\(message.messageId),seq:\(message.seq),from:\(message.from),timestamp:\(message.timestamp),text:\((message.body as? EMTextMessageBody)?.text ?? ""),isRecalled:\(message.isRecalled)")
                }
            }
        }
    }

    func inviteToJoin(_ conversationId: String) {
        EMClient.shared().conversationManager?.inviteToConversation(fromServer: conversationId, invitee: "gz1", message: "test message", completion: { result, error in
            if let error = error {
                self.printLog("invite to conversation error:\(error.errorDescription ?? "")")
            } else {
                self.printLog("invite to conversation success:\(String(describing: result))")
            }
        })
    }

    func acceptToJoin() {
        EMClient.shared().conversationManager?.decideConversationInvitation(fromServer: self.conversationIdField.text ?? "", invitationId: "1612780751797886977", accept: true, message: "test message", completion: { error in
            if let error = error {
                self.printLog("accept to conversation error:\(error.errorDescription ?? "")")
            } else {
                self.printLog("accept to conversation success")
            }
        })
    }

    func joinConversation(conversationId: String) {
        EMClient.shared().conversationManager?.joinConversation(fromServer: conversationId) { e in
        }
    }

    func createConversation() {
        let option = EMConversationCreateOptions(name: "apply test")
        option.isPublic = true
        option.inviteNeedConfirm = false
        option.needApproval = false
        option.members = ["lxm1","lxm2","lxm3","lxm4","lxm5"]
        EMClient.shared().conversationManager?.createConversation(fromServer: option) { result, e in
            if let conversationId = result?.conversation.conversationId {
                self.printLog("createConversation success,covnersationId:\(conversationId)")
            }
        }
    }

    func recallMessage() {
        EMClient.shared().chatManager?.recallMessage(withMessageId: self.messageId ?? "", ext: "包含敏感信息") { e in
        }
    }

    func modifyMessage() {
        EMClient.shared().chatManager?.modifyMessage(self.messageId ?? "", body: EMTextMessageBody(text: "new content"), ext: ["v1": 4,"v2" : 4.3, "v3" : "hello", "v4": [3,4,5,6],"v5":["sub1": "val1"]]) {
            msg,err in
        }
    }

    @objc func testAction(_ sender: Any) {
        testPageLoadMessages(cursor: nil)
    }

    // Outputs running log
    func printLog(_ log: Any...) {
        print(log)
        DispatchQueue.main.async {
            self.logView.text.append(
                DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                + ":  " + String(reflecting: log) + "\r\n"
            )
            self.logView.scrollRangeToVisible(NSRange(location: self.logView.text.count, length: 1))
        }
    }
}

extension EnvLoginTestViewController: EMLogDelegate {
    func logDidOutput(_ log: String) {
        print("sdk log:\(log)")
    }
}

extension EnvLoginTestViewController {
    func initSDK() {
        func getOptions() -> EMOptions {
            if useAppId {
                let tmp = EMOptions(appId: "f1dc778bddc646ad8f260976ca2d015c")
                return tmp
            } else {
                return EMOptions(appkey: Appkey)
            }
        }
        let options = getOptions()
        options.enableConsoleLog = true
        useSpecialServer(options)

        EMClient.shared().initializeSDK(with: options)
        EMClient.shared().add(self, delegateQueue: nil)
        EMClient.shared().chatManager?.add(self, delegateQueue: nil)
        EMClient.shared().conversationManager?.add(self, delegateQueue: nil)
    }

    func useSpecialServer(_ options: EMOptions) {
        switch env {
        case .production:
            options.setValue(true, forKey: "enableDnsConfig")
        case .dev:
            options.setValue(false, forKey: "enableDnsConfig")
            options.setValue("https://a1-hsb.easemob.com", forKey: "restServer")
            options.setValue("15.25.56.4", forKey: "chatServer")
            options.setValue(4300, forKey: "chatPort")
            options.setValue("10.34.234.2", forKey: "webSocketServer")
            options.setValue(443, forKey: "webSocketPort")
        case .tke:
            options.setValue(false, forKey: "enableDnsConfig")
            options.setValue("https://dev-shengan.easemob.net", forKey: "restServer")
            options.setValue(true, forKey: "enableTLSConnection")
            options.setValue("dev-shengan.easemob.net", forKey: "webSocketServer")
            options.setValue(8443, forKey: "webSocketPort")
        case .qa:
            options.setValue(false, forKey: "enableDnsConfig")
            options.setValue("https://a1-qa-hsb.easemob.com", forKey: "restServer")
            options.setValue(true, forKey: "enableTLSConnection")
            options.setValue("im-api-new-qa-hsb.easemob.com", forKey: "webSocketServer")
            options.setValue(443, forKey: "webSocketPort")
        }
    }

    func loginWith007Token() {
        if let userId = userIdField.text {
            let appId = "f1dc778bddc646ad8f260976ca2d015c"
            let cert = "b5a23fd8013a4db8bb06f7d1e26da789"
            let token = TokenBuilder.buildToken(withAppId: appId, cert: cert, userId: userId, expiredTime: 1000)
            EMClient.shared().login(withUsername: userId, token: token) { [weak self] (aUsername, aError) in
                if let error = aError {
                    self?.printLog("login error: \(error.errorDescription ?? "")")
                } else {
                    self?.printLog("login success")
                }
            }
        }
    }

    func renewToken() {
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

extension EnvLoginTestViewController: EMChatManagerDelegate {
    func messagesDidReceive(_ aMessages: [EMChatMessage]) {
        for message in aMessages {
            self.printLog("messagesDidReceive messageId:\(message.messageId),from:\(message.from),timestamp:\(message.timestamp),text:\((message.body as? EMTextMessageBody)?.text ?? "")")
        }
    }

    func cmdMessagesDidReceive(_ aCmdMessages: [EMChatMessage]) {
    }

    func onMessageContentChanged(_ message: EMChatMessage, operatorId: String, operationTime: UInt) {
    }

    func messageAttachmentStatusDidChange(_ aMessage: EMChatMessage, error aError: EMError?) {
        if let error = aError {
            self.printLog("messageAttachmentStatusDidChange error:\(error.errorDescription ?? "")")
        } else {
            self.printLog("messageAttachmentStatusDidChange success,messageId:\(aMessage.messageId)")
        }
    }

    func messagesInfoDidRecall(_ aRecallMessagesInfo: [EMRecallMessageInfo]) {
        self.outputUnreadMessageCount("messagesInfoDidRecall")
    }

    func messageStatusDidChange(_ aMessage: EMChatMessage, error aError: EMError?) {
    }
}

extension EnvLoginTestViewController: UIDocumentPickerDelegate {
    func sendFileMessage() {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.content", "public.text", "public.source-code", "public.image", "public.jpeg", "public.png", "com.adobe.pdf", "com.apple.keynote.key", "com.microsoft.word.doc", "com.microsoft.excel.xls", "com.microsoft.powerpoint.ppt","public.data","public.heic"], in: .open)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == UIDocumentPickerMode.open {
            guard let selectedFileURL = urls.first else {
                return
            }
            if selectedFileURL.startAccessingSecurityScopedResource() {
                if let data = FileManager.default.contents(atPath: selectedFileURL.path) {
                    let _ = FileManager.default.createFile(atPath: FileManager.default.temporaryDirectory.path + "/tmp", contents: data)
                    let fileMessageBody = EMFileMessageBody(localPath: FileManager.default.temporaryDirectory.path + "/tmp", displayName: "")
                    let msg = EMChatMessage(conversationID: self.conversationIdField.text ?? "", body: fileMessageBody, ext: ["originExtKey":"originExtValue"])
                    EMClient.shared().chatManager?.send(msg, progress: { progress in
                        self.printLog("send file message progress:\(progress)")
                    }) {
                        [weak self] msg, err in
                        if let error = err {
                            self?.printLog("send file message error: \(error.errorDescription ?? "")")
                        } else {
                            self?.messageId = msg?.messageId ?? ""
                            self?.printLog("send file message success")
                        }
                    }
                }
                selectedFileURL.stopAccessingSecurityScopedResource()
            } else {
                printLog("permission disable")
            }
        }
    }

    func filePath() -> String {
        var path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        path = (path as NSString).appendingPathComponent("appdata/chatbuffer/")
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }

        return path
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    }
}

extension EnvLoginTestViewController: UIImagePickerControllerDelegate {
    func sendImageMessage() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        imagePicker.modalPresentationStyle = .fullScreen
        self.present(imagePicker, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let sendImage: (EMImageMessageBody) -> Void = { [weak self] imageData in
            guard let self else {
                return
            }

            for _ in 0...0 {
                let msg = EMChatMessage(conversationID: self.conversationIdField.text ?? "", body: imageData, ext: nil)
                EMClient.shared().chatManager?.send(msg, progress: nil) {
                    [weak self] msg, err in
                    if  err == nil {
                        let status = (msg?.body as? EMImageMessageBody)?.thumbnailDownloadStatus.rawValue ?? -1
                        self?.printLog("thumbnailDownloadStatus:\(status)")
                    }
                }
            }
        }

        if let imageURL = info[.imageURL] as? URL,let data = try? Data(contentsOf: imageURL) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(Date().timeIntervalSince1970).jpg")
            FileManager.default.createFile(atPath: tempURL.path, contents: data, attributes: nil)
            let imageData = EMImageMessageBody(localPath: imageURL.path, displayName: "")
            imageData.compressionRatio = 1
            sendImage(imageData)
        } else if let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 1.0) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tmp.jpg")
            FileManager.default.createFile(atPath: tempURL.path, contents: data, attributes: nil)
            let imageData = EMImageMessageBody(localPath: tempURL.path, displayName: "")
            sendImage(imageData)
        }
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension EnvLoginTestViewController: EMClientDelegate {
    func connectionStateDidChange(_ aConnectionState: EMConnectionState) {
        if aConnectionState == .connected {
            printLog("EMClientDelegate: aConnectionState:connected")
        } else {
            printLog("EMClientDelegate: aConnectionState:disconnected")
        }
    }

    func onOfflineMessageSyncStart() {
        self.printLog("EMClientDelegate:onOfflineMessageSyncStart")
    }

    func onOfflineMessageSyncFinish() {
        self.printLog("EMClientDelegate:onOfflineMessageSyncFinish")
    }

    func tokenDidExpire(_ aErrorCode: EMErrorCode) {
        DispatchQueue.main.async {
            self.renewToken()
        }
    }

    func tokenWillExpire(_ aErrorCode: EMErrorCode) {
        // 通过AppServer获取新的token,然后调用sdk的renewToken方法
    }

    // 用户账户已经被移除
    func userAccountDidRemoveFromServer() {
    }

    // 用户账户被禁用
    func userDidForbidByServer() {
    }

    // 当前账号被强制退出登录，有以下原因：密码被修改；登录设备数过多；服务被封禁; 被强制下线;
    func userAccountDidForced(toLogout aError: EMError?) {
        EMClient.shared().logout(false)
    }

    func autoLoginDidCompleteWithError(_ aError: EMError?) {
    }

    func onDatabaseOpened(_ error: EMError?, username: String) {
        self.printLog("onDatabaseOpened username:\(username),error:\(error?.errorDescription ?? "nil")")
    }
}

extension EnvLoginTestViewController: EMConversationManagerDelegate {
    func onConversationEvents(_ aEvents: [EMConversationEvent]) {
        for event in aEvents {
            self.printLog("onConversationEvents event:\(event.toJson())")
        }
    }

    func onCallCreate(_ aConversationId: String, callId aCallId: String) {
        self.printLog("onCallCreate conversationId:\(aConversationId),callId:\(aCallId)")
    }

    func onCallEnd(_ aConversationId: String, callId aCallId: String) {
        self.printLog("onCallEnd conversationId:\(aConversationId),callId:\(aCallId)")
    }
}

extension EMConversationEvent {
    func toJson() -> [String: Any] {
        let json: [String: Any] = [
            "conversationId": self.conversationId,
            "eventId": self.eventId,
            "seq": self.seq,
            "timestamp": self.timestamp,
            "namespace": self.nameSpace,
            "operation": self.operation,
            "operatorId": self.operatorId,
            "ext": self.ext,
            "reason": self.reason,
            "targetids": self.targets
        ]
        return json
    }
}
