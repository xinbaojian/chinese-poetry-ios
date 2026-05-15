import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RegisterRequest: Encodable {
    let username: String
    let password: String
}

struct ChangePasswordRequest: Encodable {
    let oldPassword: String
    let newPassword: String
}

struct AuthResponse: Decodable {
    let token: String
    let refreshToken: String
    let user: UserInfo

    enum CodingKeys: String, CodingKey {
        case token
        case refreshToken = "refresh_token"
        case user
    }
}

struct UserInfo: Decodable {
    let id: UInt64
    let username: String
    let role: String
}

private struct MessageResponse: Decodable {
    let message: String
}

struct AuthService {
    static func register(username: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await APIClient.shared.request(
            "/auth/register",
            method: "POST",
            body: RegisterRequest(username: username, password: password)
        )
        APIClient.shared.token = response.token
        APIClient.shared.refreshToken = response.refreshToken
        return response
    }

    static func login(username: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await APIClient.shared.request(
            "/auth/login",
            method: "POST",
            body: LoginRequest(username: username, password: password)
        )
        APIClient.shared.token = response.token
        APIClient.shared.refreshToken = response.refreshToken
        return response
    }

    static func logout() async {
        guard let rt = APIClient.shared.refreshToken else {
            APIClient.shared.clearAuth()
            return
        }
        // 调用 API 吊销 refresh_token，失败也清除本地
        let _: MessageResponse? = try? await APIClient.shared.request(
            "/auth/logout",
            method: "POST",
            body: RefreshRequest(refreshToken: rt),
            retry: false
        )
        APIClient.shared.clearAuth()
    }

    static func changePassword(oldPassword: String, newPassword: String) async throws {
        let _: MessageResponse = try await APIClient.shared.request(
            "/auth/password",
            method: "PUT",
            body: ChangePasswordRequest(oldPassword: oldPassword, newPassword: newPassword)
        )
        // 修改密码后 refresh_token 全部失效，清除本地令牌
        APIClient.shared.clearAuth()
    }

    static var isLoggedIn: Bool {
        APIClient.shared.token != nil
    }
}
