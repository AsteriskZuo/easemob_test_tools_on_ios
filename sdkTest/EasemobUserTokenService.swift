//
//  EasemobUserTokenService.swift
//  sdkTest
//

import Foundation

struct EasemobUserTokenRequest {
    let baseURL: String
    let appKey: String
    let username: String
    let password: String
    let bearerToken: String
}

struct EasemobUserTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

enum EasemobUserTokenError: LocalizedError {
    case missingField(String)
    case invalidBaseURL
    case invalidAppKey
    case invalidHTTPResponse
    case server(statusCode: Int, message: String)
    case invalidTokenResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "Missing required field: \(field)"
        case .invalidBaseURL:
            return "Base URL must be a valid HTTP or HTTPS URL"
        case .invalidAppKey:
            return "AppKey must use the org#app format"
        case .invalidHTTPResponse:
            return "Token server returned an invalid HTTP response"
        case .server(let statusCode, let message):
            return "Token request failed (HTTP \(statusCode)): \(message)"
        case .invalidTokenResponse:
            return "Token response does not contain a valid access_token"
        case .transport(let message):
            return "Token request failed: \(message)"
        }
    }
}

final class EasemobUserTokenService {
    static let shared = EasemobUserTokenService()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchToken(_ request: EasemobUserTokenRequest) async throws -> EasemobUserTokenResponse {
        let url = try tokenURL(baseURL: request.baseURL, appKey: request.appKey)
        let username = try required(request.username, field: "username")
        let password = try required(request.password, field: "password")
        let bearerToken = try required(request.bearerToken, field: "bearerToken")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(authorizationHeader(for: bearerToken), forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode([
            "grant_type": "password",
            "username": username,
            "password": password
        ])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw EasemobUserTokenError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EasemobUserTokenError.invalidHTTPResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw EasemobUserTokenError.server(
                statusCode: httpResponse.statusCode,
                message: serverErrorMessage(from: data)
            )
        }

        guard let tokenResponse = try? JSONDecoder().decode(EasemobUserTokenResponse.self, from: data),
              !tokenResponse.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EasemobUserTokenError.invalidTokenResponse
        }
        return tokenResponse
    }

    private func tokenURL(baseURL: String, appKey: String) throws -> URL {
        let normalizedBaseURL = try required(baseURL, field: "baseURL")
        guard let url = URL(string: normalizedBaseURL),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            throw EasemobUserTokenError.invalidBaseURL
        }

        let parts = appKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw EasemobUserTokenError.invalidAppKey
        }

        return url
            .appendingPathComponent(String(parts[0]))
            .appendingPathComponent(String(parts[1]))
            .appendingPathComponent("token")
    }

    private func required(_ value: String, field: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw EasemobUserTokenError.missingField(field)
        }
        return normalized
    }

    private func authorizationHeader(for token: String) -> String {
        token.lowercased().hasPrefix("bearer ") ? token : "Bearer \(token)"
    }

    private func serverErrorMessage(from data: Data) -> String {
        guard let payload = try? JSONDecoder().decode(ServerErrorPayload.self, from: data) else {
            return String(data: data, encoding: .utf8) ?? "Unknown server error"
        }
        return payload.errorDescription ?? payload.error ?? payload.message ?? "Unknown server error"
    }
}

private struct ServerErrorPayload: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case message
    }
}
