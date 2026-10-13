//
//  SendImageMessageTest.swift
//  独立测试：初始化 SDK、登录、发送图片消息、退出登录
//
//  Created on 2026-07-28.
//

import SwiftUI
import PhotosUI
import HyphenateChat

// MARK: - 测试常量（按需自行修改）

/// Appkey，参考 ViewController.swift 中的 Appkey
private let kAppKey = "easemob-demo#zuoyu"
/// 登录用户名
private let kLoginUsername = "zuoyu01"
/// 5.0 移除了密码登录，改用 TokenBuilder 现场生成 token（appId/cert 与 ViewController.loginWith007Token() 一致）
private let kAppId = "3f7718b6a2eb45e5b3bc82ee6fee3504"
private let kTokenCert = "02d09b6c08fb4988a789465ac48a66c9"
/// 图片消息接收方（单聊会话 ID）
private let kReceiverId = "zuoyu02"

struct SendImageMessageTest: View {
    @State private var testResults: [String] = []
    @State private var isSDKInitialized = false
    @State private var isLoggedIn = false
    @State private var isSending = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var showingImagePicker = false
    @State private var showingLegacyImagePicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("发送图片消息测试")
                .font(.title)
                .padding(.top)
            
            // 状态指示
            HStack(spacing: 16) {
                Label(isSDKInitialized ? "已初始化" : "未初始化",
                      systemImage: isSDKInitialized ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSDKInitialized ? .green : .secondary)
                Label(isLoggedIn ? "已登录" : "未登录",
                      systemImage: isLoggedIn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isLoggedIn ? .green : .secondary)
            }
            .font(.subheadline)
            
            // 初始化按钮
            Button(action: initSDK) {
                HStack {
                    Image(systemName: "power")
                    Text("1. 初始化 SDK")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isSDKInitialized)
            
            // 登录按钮
            Button(action: login) {
                HStack {
                    Image(systemName: "person.fill")
                    Text("2. 登录")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!isSDKInitialized || isLoggedIn)
            
            // 选择图片并发送按钮
            Button(action: {
                if #available(iOS 16.0, *) {
                    showingImagePicker = true
                } else {
                    showingLegacyImagePicker = true
                }
            }) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text(isSending ? "发送中..." : "3. 选择图片并发送")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!isLoggedIn || isSending)
            
            // 退出登录按钮
            Button(action: logout) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("4. 退出登录")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!isLoggedIn)
            
            // 清除日志按钮
            Button(action: { testResults.removeAll() }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清除日志")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // 日志区域
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                        Text(result)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding()
            }
        }
        .padding(.horizontal)
        .photosPicker(isPresented: $showingImagePicker,
                     selection: $selectedImages,
                     maxSelectionCount: 1,
                     matching: .images)
        .sheet(isPresented: $showingLegacyImagePicker) {
            LegacyImagePicker { urls in
                if let url = urls.first {
                    sendImageMessage(localPath: url.path, displayName: url.lastPathComponent)
                }
            }
        }
        .onChange(of: selectedImages) { _, newImages in
            if let item = newImages.first {
                handleSelectedImage(item)
            }
        }
    }
    
    // MARK: - SDK 接口调用（参考 ViewController.swift）
    
    private func initSDK() {
        // 避免与"SDK 测试"页面重复初始化
        guard !SendImageMessageTestState.didInitSDK else {
            isSDKInitialized = true
            log("SDK 已初始化过，跳过")
            return
        }
        
        let options = EMOptions(appkey: kAppKey)
        options.enableConsoleLog = true
        // 5.0 移除 EMOptions.isAutoLogin：自动登录不再可关，token 过期用 EMClient.renewToken(_:)
        options.usingHttpsOnly = false
        
        EMClient.shared().initializeSDK(with: options)
        SendImageMessageTestState.didInitSDK = true
        isSDKInitialized = true
        log("初始化成功，appkey: \(kAppKey)")
    }
    
    private func login() {
        guard !kAppId.isEmpty, !kTokenCert.isEmpty else {
            log("请先在 SendImageMessageTest.swift 中填写 kAppId 和 kTokenCert")
            return
        }
        let token = TokenBuilder.buildToken(withAppId: kAppId, cert: kTokenCert, userId: kLoginUsername, expiredTime: 3600)
        log("登录中: \(kLoginUsername) ...")
        EMClient.shared().login(withUsername: kLoginUsername, token: token) { username, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.log("登录失败: \(error.errorDescription ?? "") (code: \(error.code.rawValue))")
                } else {
                    self.isLoggedIn = true
                    self.log("登录成功: \(username)")
                }
            }
        }
    }
    
    private func logout() {
        EMClient.shared().logout(false) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.log("退出登录失败: \(error.errorDescription ?? "") (code: \(error.code.rawValue))")
                } else {
                    self.isLoggedIn = false
                    self.log("退出登录成功")
                }
            }
        }
    }
    
    // MARK: - 图片选择与发送（相册选择参考 MediaFilePickerTest.swift）
    
    private func handleSelectedImage(_ item: PhotosPickerItem) {
        // 清空选择以便下次使用
        selectedImages.removeAll()
        
        log("获取图片数据...")
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let imageData = data else {
                        self.log("错误: 无法获取图片数据")
                        return
                    }
                    self.log("图片大小: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")
                    
                    // 保存到临时目录后按本地路径发送
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("send_image_\(Int(Date().timeIntervalSince1970)).jpg")
                    do {
                        try imageData.write(to: tempURL)
                        self.sendImageMessage(localPath: tempURL.path, displayName: tempURL.lastPathComponent)
                    } catch {
                        self.log("保存临时文件失败: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    self.log("读取图片失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func sendImageMessage(localPath: String, displayName: String) {
        isSending = true
        log("发送图片消息到 \(kReceiverId) ...")
        log("  本地路径: \(localPath)")
        let displayName = ""
        
        let imageBody = EMImageMessageBody(localPath: localPath, displayName: displayName)
        let message = EMChatMessage(conversationID: kReceiverId, body: imageBody, ext: nil)
        EMClient.shared().chatManager?.send(message, progress: { progress in
            DispatchQueue.main.async {
                self.log("  上传进度: \(progress)%")
            }
        }, completion: { message, error in
            DispatchQueue.main.async {
                self.isSending = false
                if let error = error {
                    self.log("发送失败: \(error.errorDescription ?? "") (code: \(error.code.rawValue))")
                } else {
                    self.log("发送成功，messageId: \(message?.messageId ?? "")")
                }
            }
        })
    }
    
    private func log(_ message: String) {
        testResults.append(message)
    }
}

// MARK: - 全局初始化标记（进程内只初始化一次）

private enum SendImageMessageTestState {
    static var didInitSDK = false
}

#Preview {
    SendImageMessageTest()
}
