import Foundation
import os

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(String, Int)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "登录已过期，请重新登录"
        case .serverError(let msg, _): return msg
        case .invalidResponse: return "网络响应异常"
        case .networkError(let msg): return "网络错误：\(msg)"
        }
    }
}

struct ErrorResponse: Decodable {
    let error: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

class APIClient {
    static let shared = APIClient()
    private static let logger = Logger(subsystem: "com.poetry.app", category: "API")

    private var _token: String?
    var token: String? {
        get { _token }
        set {
            _token = newValue
            if let newValue {
                KeychainHelper.save(token: newValue)
            } else {
                KeychainHelper.deleteToken()
            }
        }
    }

    private var _refreshToken: String?
    var refreshToken: String? {
        get { _refreshToken }
        set {
            _refreshToken = newValue
            if let newValue {
                KeychainHelper.saveRefreshToken(newValue)
            } else {
                KeychainHelper.deleteRefreshToken()
            }
        }
    }

    var baseURL: String {
        UserDefaults.standard.string(forKey: "serverBaseURL") ?? "https://poetry.xiuyuan.xin"
    }

    /// 并发刷新时复用同一个 Task，避免多个请求同时触发刷新
    private var refreshTask: Task<AuthResponse, Error>?

    private init() {
        _token = KeychainHelper.loadToken()
        _refreshToken = KeychainHelper.loadRefreshToken()
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        retry: Bool = true
    ) async throws -> T {
        guard !baseURL.isEmpty else {
            throw APIError.networkError("服务器地址未配置")
        }

        let url = try buildURL(path)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 15

        if let token = _token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
        }

        Self.logger.info("\(method) \(url.absoluteString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            Self.logger.error("Network error: \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // 401 且有 refresh_token：尝试刷新后重试
        if http.statusCode == 401 && retry {
            if let refreshed = try? await refreshTokens() {
                token = refreshed.token
                refreshToken = refreshed.refreshToken
                return try await request(path, method: method, body: body, retry: false)
            } else {
                clearAuth()
                throw APIError.unauthorized
            }
        }

        if !(200...299).contains(http.statusCode) {
            let err = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(err?.error ?? "未知错误", http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func buildURL(_ path: String) throws -> URL {
        var urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        urlString += "/api/v1\(path)"
        if !urlString.hasPrefix("http") {
            urlString = "https://\(urlString)"
        }
        guard let url = URL(string: urlString) else {
            Self.logger.error("Invalid URL: \(urlString)")
            throw APIError.networkError("无效的 URL")
        }
        return url
    }

    /// 刷新令牌，并发请求复用同一个 Task
    private func refreshTokens() async throws -> AuthResponse {
        if let existing = refreshTask {
            return try await existing.value
        }

        guard let rt = _refreshToken else {
            throw APIError.unauthorized
        }

        let task = Task<AuthResponse, Error> { [self] in
            let url = try buildURL("/auth/refresh")
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.timeoutInterval = 15
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(RefreshRequest(refreshToken: rt))

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: urlRequest)
            } catch {
                throw APIError.unauthorized
            }

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw APIError.unauthorized
            }

            return try JSONDecoder().decode(AuthResponse.self, from: data)
        }

        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    /// 清除认证状态
    func clearAuth() {
        token = nil
        refreshToken = nil
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
    }
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
