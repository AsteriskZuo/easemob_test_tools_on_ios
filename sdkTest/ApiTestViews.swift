//
//  ApiTestViews.swift
//  sdkTest
//
//  API 调用测试页：列表页按关键字过滤注册表，调用页编辑 JSON 参数后调用并展示结果。
//

import SwiftUI
import UIKit

/// API 列表页：关键字过滤（匹配名称与分组，大小写不敏感），点行弹出调用页。
struct ApiTestListView: View {
    @ObservedObject private var session = SDKLoginState.shared
    @State private var query = ""
    @State private var selected: ApiEntry?

    private var results: [ApiEntry] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return apiRegistry }
        return apiRegistry.filter {
            $0.name.lowercased().contains(keyword) || $0.group.lowercased().contains(keyword)
        }
    }

    var body: some View {
        Form {
            Section("SDK 状态") {
                Text("初始化：\(session.initialized ? "已完成" : "未完成（请到「登录与初始化」页面操作）")")
                Text("登录：\(session.loggedIn ? session.username : "未登录")")
                Text("初始化与登录在「登录与初始化」页面完成，此处共享其状态。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("API 列表（\(results.count)/\(apiRegistry.count)）") {
                TextField("输入关键字过滤，如 send / Chat", text: $query)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                ForEach(results) { entry in
                    Button {
                        selected = entry
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name).foregroundStyle(.primary)
                            Text(entry.group).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("API 调用")
        .onAppear { session.refresh() }
        .sheet(item: $selected) { entry in
            NavigationStack {
                ApiTestCallView(entry: entry)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") { selected = nil }
                        }
                    }
            }
        }
    }
}

/// API 调用页：JSON 参数预填必填字段模板，结果为格式化 JSON（可选择、复制），同时输出到 Xcode 控制台（[APITester]）。
struct ApiTestCallView: View {
    let entry: ApiEntry
    @State private var paramsText: String
    @State private var resultText: String?
    @State private var running = false

    init(entry: ApiEntry) {
        self.entry = entry
        _paramsText = State(initialValue: entry.paramsTemplate)
    }

    var body: some View {
        Form {
            Section("说明") {
                Text(entry.detail).font(.callout)
            }
            Section("参数 JSON（必填字段模板）") {
                TextEditor(text: $paramsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Section {
                Button(running ? "调用中…" : "调用") { invoke() }
                    .disabled(running)
            }
            if let resultText {
                Section("结果") {
                    Button("复制全文") { UIPasteboard.general.string = resultText }
                    Text(resultText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(entry.name)
    }

    private func invoke() {
        running = true
        resultText = nil
        Task { @MainActor in
            let result: [String: Any]
            do {
                let data = Data(paramsText.utf8)
                guard let params = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw ApiInvokeError(code: -1, message: "参数必须是 JSON Object")
                }
                result = await runApi(entry, params: params)
            } catch let error as ApiInvokeError {
                result = ["success": false, "error": ["code": error.code, "message": error.message]]
            } catch {
                result = ["success": false, "error": ["code": -1, "message": error.localizedDescription]]
            }
            let text = prettyJson(result)
            consoleLogChunked("[APITester]", "api.\(entry.name) \(text)")
            running = false
            resultText = text
        }
    }
}

/// 结果统一格式化为美化 JSON；无法序列化时退回描述文本。
private func prettyJson(_ value: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
          let text = String(data: data, encoding: .utf8) else {
        return String(describing: value)
    }
    return text
}
