import Foundation

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

class APIClient {
    static let shared = APIClient()

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

    var baseURL: String {
        UserDefaults.standard.string(forKey: "serverBaseURL") ?? "https://poetry.xiuyuan.xin"
    }

    private init() {
        _token = KeychainHelper.loadToken()
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard !baseURL.isEmpty else {
            throw APIError.networkError("服务器地址未配置")
        }

        var urlString = "\(baseURL)/api/v1\(path)"
        if !urlString.hasPrefix("http") {
            urlString = "https://\(urlString)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.networkError("无效的 URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if let token = _token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 {
            token = nil
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            throw APIError.unauthorized
        }

        if !(200...299).contains(http.statusCode) {
            let err = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(err?.error ?? "未知错误", http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
