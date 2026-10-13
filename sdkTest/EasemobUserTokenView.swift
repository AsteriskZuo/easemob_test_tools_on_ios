//
//  EasemobUserTokenView.swift
//  sdkTest
//

import SwiftUI
import UIKit

struct EasemobUserTokenView: View {
    @StateObject private var viewModel = EasemobUserTokenViewModel()
    private let onTokenFetched: ((String) -> Void)?

    init(onTokenFetched: ((String) -> Void)? = nil) {
        self.onTokenFetched = onTokenFetched
    }

    var body: some View {
        Form {
            EasemobUserTokenForm(
                viewModel: viewModel,
                onTokenFetched: onTokenFetched
            )
        }
        .navigationTitle("用户 Token")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EasemobUserTokenForm: View {
    @ObservedObject var viewModel: EasemobUserTokenViewModel
    var isAppKeyLocked = false
    var onTokenFetched: ((String) -> Void)?

    var body: some View {
        Group {
            Section("Token 配置") {
                TextField("Base URL", text: $viewModel.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("AppKey（org#app）", text: $viewModel.appKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isAppKeyLocked)
                TextField("用户名", text: $viewModel.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("密码", text: $viewModel.password)
                SecureField("Bearer Token", text: $viewModel.bearerToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("用户 Token（可手动粘贴）", text: $viewModel.accessToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Token 结果") {
                Button {
                    viewModel.fetchToken(onSuccess: onTokenFetched)
                } label: {
                    Label(viewModel.isLoading ? "获取中" : "获取用户 Token", systemImage: "key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)

                HStack {
                    Text(viewModel.status)
                        .foregroundStyle(viewModel.didFail ? Color.red : Color.secondary)
                    Spacer()
                    if !viewModel.accessToken.isEmpty {
                        Button {
                            UIPasteboard.general.string = viewModel.accessToken
                            viewModel.markCopied()
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .accessibilityLabel("复制用户 Token")
                    }
                }

                if !viewModel.accessToken.isEmpty {
                    Text(viewModel.accessToken)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
    }
}

@MainActor
final class EasemobUserTokenViewModel: ObservableObject {
    @Published var baseURL = "https://ngi-a1.easemob.com"
    @Published var appKey = "easemob-demo#zuoyu"
    @Published var username = "zuoyu01"
    @Published var password = ""
    @Published var bearerToken = ""
    @Published var accessToken = ""
    @Published private(set) var status = "尚未请求"
    @Published private(set) var didFail = false
    @Published private(set) var isLoading = false

    func fetchToken(onSuccess: ((String) -> Void)?) {
        Task {
            do {
                let response = try await fetchToken()
                onSuccess?(response.accessToken)
            } catch {
                // fetchToken() already exposes the error through published state.
            }
        }
    }

    func fetchToken() async throws -> EasemobUserTokenResponse {
        isLoading = true
        didFail = false
        status = "正在请求"

        let request = EasemobUserTokenRequest(
            baseURL: baseURL,
            appKey: appKey,
            username: username,
            password: password,
            bearerToken: bearerToken
        )

        do {
            let response = try await EasemobUserTokenService.shared.fetchToken(request)
            accessToken = response.accessToken
            isLoading = false
            if let expiresIn = response.expiresIn {
                status = "获取成功，有效期 \(expiresIn) 秒"
            } else {
                status = "获取成功"
            }
            return response
        } catch {
            isLoading = false
            didFail = true
            status = error.localizedDescription
            throw error
        }
    }

    func resolveAccessToken() async throws -> String {
        let existingToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existingToken.isEmpty {
            return existingToken
        }
        return try await fetchToken().accessToken
    }

    func markCopied() {
        status = "已复制"
    }
}

struct EasemobUserTokenView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EasemobUserTokenView()
        }
    }
}
