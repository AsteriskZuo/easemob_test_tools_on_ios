//
//  MediaFilePickerTest.swift
//  测试相册和文件管理器路径获取
//
//  Created on 2025-09-15.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import HyphenateChat

struct MediaFilePickerTest: View {
    @State private var testResults: [String] = []
    @State private var isRunning = false
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var showingLegacyImagePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("媒体文件路径测试")
                    .font(.title)
                    .padding()
                
                // 相册选择器按钮 - 使用兼容版本
                Button(action: {
                    if #available(iOS 16.0, *) {
                        showingImagePicker = true
                    } else {
                        showingLegacyImagePicker = true
                    }
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("选择相册图片")
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // 文件管理器按钮
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("选择文件")
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // 清除结果按钮
                Button(action: clearResults) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清除结果")
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
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
                
                Spacer()
            }
        }
        .photosPicker(isPresented: $showingImagePicker, 
                     selection: $selectedImages, 
                     maxSelectionCount: 5,
                     matching: .images)
        .fileImporter(isPresented: $showingDocumentPicker,
                     allowedContentTypes: [.item],
                     allowsMultipleSelection: true) { result in
            DispatchQueue.main.async {
                handleDocumentPickerResult(result)
            }
        }
        .sheet(isPresented: $showingLegacyImagePicker) {
            LegacyImagePicker { urls in
                handleLegacyImageSelection(urls)
            }
        }
        .onChange(of: selectedImages) { _, newImages in
            if !newImages.isEmpty {
                handleSelectedImages(newImages)
            }
        }
    }
    
    private func clearResults() {
        testResults.removeAll()
    }
    
    private func handleSelectedImages(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        
        isRunning = true
        testResults.append("\n=== 相册图片路径分析开始 ===")
        testResults.append("选择了 \(items.count) 张图片\n")
        
        let resolver = IOSPathResolver.shared()
        
        for (index, item) in items.enumerated() {
            testResults.append("图片 \(index + 1):")
            testResults.append("  标识符: \(item.itemIdentifier ?? "未知")")
            
            // 尝试获取图片数据和路径信息
            item.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data):
                        if let imageData = data {
                            self.testResults.append("  数据大小: \(self.formatFileSize(imageData.count))")
                            
                            // 尝试保存到临时目录并获取路径
                            let tempURL = self.saveToTempDirectory(data: imageData, 
                                                                 identifier: item.itemIdentifier ?? "unknown",
                                                                 index: index)
                            if let tempPath = tempURL?.path {
                                self.testResults.append("  临时保存路径: \(tempPath)")
                                
                                // 使用路径解析器分析
                                let pathInfo = resolver.resolvePathInfo(tempPath)
                                self.testResults.append("  路径类型: \(resolver.pathTypeDescription(pathInfo.pathType))")
                                self.testResults.append("  文件存在: \(pathInfo.exists ? "是" : "否")")
                                self.testResults.append("  文件大小验证: \(self.verifyFileSize(at: tempPath, expectedSize: imageData.count))")
                            }
                        } else {
                            self.testResults.append("  错误: 无法获取图片数据")
                        }
                    case .failure(let error):
                        self.testResults.append("  错误: \(error.localizedDescription)")
                    }
                    
                    if index == items.count - 1 {
                        self.testResults.append("\n=== 相册图片路径分析完成 ===")
                        self.isRunning = false
                    }
                }
            }
        }
        
        // 清空选择以便下次使用
        selectedImages.removeAll()
    }
    
    private func handleDocumentPickerResult(_ result: Result<[URL], Error>) {
        isRunning = true
        testResults.append("\n=== 文件管理器路径分析开始 ===")
        
        let resolver = IOSPathResolver.shared()
        
        switch result {
        case .success(let urls):
            testResults.append("选择了 \(urls.count) 个文件\n")
            
            for (index, url) in urls.enumerated() {
                testResults.append("文件 \(index + 1):")
                testResults.append("  原始URL: \(url.absoluteString)")
                testResults.append("  文件名: \(url.lastPathComponent)")
                testResults.append("  文件扩展名: \(url.pathExtension)")
                
                // 开始访问安全范围资源 - 添加错误处理
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                // 使用路径解析器分析
                let pathInfo = resolver.resolvePathInfo(url.path)
                testResults.append("  本地路径: \(url.path)")
                testResults.append("  本地路径2: \(String(describing: pathInfo.resolvedPath))")
                testResults.append("  路径类型: \(resolver.pathTypeDescription(pathInfo.pathType))")
                testResults.append("  文件存在: \(pathInfo.exists ? "是" : "否")")
                
                if pathInfo.originalPath.isEmpty != true {
                    sendFileMessage(path: pathInfo.originalPath)
                }
                
                if pathInfo.exists {
                    testResults.append("  是目录: \(pathInfo.isDirectory ? "是" : "否")")
                    testResults.append("  可读取: \(pathInfo.isReadable ? "是" : "否")")
                    testResults.append("  可写入: \(pathInfo.isWritable ? "是" : "否")")
                    
                    // 获取文件属性 - 添加错误处理
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        if let fileSize = attributes[.size] as? Int64 {
                            testResults.append("  文件大小: \(formatFileSize(Int(fileSize)))")
                        }
                        if let modificationDate = attributes[.modificationDate] as? Date {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .medium
                            testResults.append("  修改时间: \(formatter.string(from: modificationDate))")
                        }
                    } catch {
                        testResults.append("  获取文件属性失败: \(error.localizedDescription)")
                    }
                    
                    // 尝试复制到应用沙盒进行进一步测试 - 只对小文件进行
                    if !pathInfo.isDirectory {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                            if let fileSize = attributes[.size] as? Int64, fileSize < 10_000_000 { // 10MB限制
                                let copiedURL = copyToAppDirectory(from: url, index: index)
                                if let copiedPath = copiedURL?.path {
                                    testResults.append("  已复制到应用目录: \(copiedPath)")
                                    let copiedInfo = resolver.resolvePathInfo(copiedPath)
                                    testResults.append("  复制后路径类型: \(resolver.pathTypeDescription(copiedInfo.pathType))")
                                }
                            } else {
                                testResults.append("  文件过大，跳过复制测试")
                            }
                        } catch {
                            testResults.append("  复制测试跳过: 无法获取文件大小")
                        }
                    }
                }
                
                if let error = pathInfo.error {
                    testResults.append("  路径解析错误: \(error.localizedDescription)")
                }
                
                testResults.append("")
            }
            
        case .failure(let error):
            testResults.append("选择文件失败: \(error.localizedDescription)")
            // 如果是FileProvider错误，提供解决建议
            if error.localizedDescription.contains("FileProvider") {
                testResults.append("建议: 请尝试选择存储在本地的文件，而不是iCloud或其他云存储中的文件")
            }
        }
        
        testResults.append("=== 文件管理器路径分析完成 ===")
        isRunning = false
    }
    
    private func handleLegacyImageSelection(_ urls: [URL]) {
        isRunning = true
        testResults.append("\n=== 相册图片路径分析开始 (Legacy模式) ===")
        testResults.append("选择了 \(urls.count) 张图片\n")
        
        let resolver = IOSPathResolver.shared()
        
        for (index, url) in urls.enumerated() {
            testResults.append("图片 \(index + 1):")
            testResults.append("  URL: \(url.absoluteString)")
            testResults.append("  文件名: \(url.lastPathComponent)")
            
            let pathInfo = resolver.resolvePathInfo(url.path)
            testResults.append("  路径类型: \(resolver.pathTypeDescription(pathInfo.pathType))")
            testResults.append("  文件存在: \(pathInfo.exists ? "是" : "否")")
            
            if pathInfo.exists {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        testResults.append("  文件大小: \(formatFileSize(Int(fileSize)))")
                    }
                } catch {
                    testResults.append("  获取文件大小失败: \(error.localizedDescription)")
                }
            }
            testResults.append("")
        }
        
        testResults.append("=== 相册图片路径分析完成 ===")
        isRunning = false
    }
    
    private func saveToTempDirectory(data: Data, identifier: String, index: Int) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "photo_\(index)_\(identifier.prefix(8)).jpg"
        let tempURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            testResults.append("  保存到临时目录失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func copyToAppDirectory(from sourceURL: URL, index: Int) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask).first!
        let fileName = "copied_file_\(index)_\(sourceURL.lastPathComponent)"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            // 如果文件已存在，先删除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            testResults.append("  复制文件失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func verifyFileSize(at path: String, expectedSize: Int) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let actualSize = attributes[.size] as? Int64 {
                return actualSize == expectedSize ? "✅ 匹配" : "❌ 不匹配 (实际: \(actualSize))"
            }
        } catch {
            return "❌ 验证失败: \(error.localizedDescription)"
        }
        return "❌ 未知错误"
    }
    
    private func sendFileMessage(path: String) {
        let msgBody = EMFileMessageBody(localPath: path, displayName: "test.file");
        EMClient.shared().chatManager?.send(EMChatMessage(conversationID: "asterisk003", body: msgBody, ext: nil), progress: nil, completion: { message, error in
            if let error = error {
                // 打印到控制台
                print("发送文件失败: \(error.description) \(error.code)")
            } else {
                // 打印到控制台
                print("发送文件成功: \(message?.messageId ?? "")")
            }
        })
    }
}

// MARK: - Legacy Image Picker for iOS compatibility
struct LegacyImagePicker: UIViewControllerRepresentable {
    let completion: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: LegacyImagePicker
        
        init(_ parent: LegacyImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            
            if let imageUrl = info[.imageURL] as? URL {
                parent.completion([imageUrl])
            } else if let image = info[.originalImage] as? UIImage {
                // 如果没有URL，保存到临时目录
                let tempURL = saveImageToTemp(image)
                if let url = tempURL {
                    parent.completion([url])
                } else {
                    parent.completion([])
                }
            } else {
                parent.completion([])
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.completion([])
        }
        
        private func saveImageToTemp(_ image: UIImage) -> URL? {
            guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "legacy_photo_\(Date().timeIntervalSince1970).jpg"
            let tempURL = tempDir.appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
                return tempURL
            } catch {
                return nil
            }
        }
    }
}

#Preview {
    MediaFilePickerTest()
}
