import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RegisterRequest: Encodable {
    let username: String
    let password: String
}

struct AuthResponse: Decodable {
    let token: String
    let user: UserInfo
}

struct UserInfo: Decodable {
    let id: UInt64
    let username: String
    let role: String
}

struct AuthService {
    static func register(username: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await APIClient.shared.request(
            "/auth/register",
            method: "POST",
            body: RegisterRequest(username: username, password: password)
        )
        APIClient.shared.token = response.token
        return response
    }

    static func login(username: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await APIClient.shared.request(
            "/auth/login",
            method: "POST",
            body: LoginRequest(username: username, password: password)
        )
        APIClient.shared.token = response.token
        return response
    }

    static func logout() {
        APIClient.shared.token = nil
    }

    static var isLoggedIn: Bool {
        APIClient.shared.token != nil
    }
}
