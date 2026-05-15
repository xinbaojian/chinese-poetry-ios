import Foundation
import Security

struct KeychainHelper {
    private static let service = "com.poetry.app"
    private static let tokenAccount = "auth_token"
    private static let refreshTokenAccount = "refresh_token"

    // MARK: - Access Token

    static func save(token: String) {
        save(token, account: tokenAccount)
    }

    static func loadToken() -> String? {
        load(account: tokenAccount)
    }

    static func deleteToken() {
        delete(account: tokenAccount)
    }

    // MARK: - Refresh Token

    static func saveRefreshToken(_ token: String) {
        save(token, account: refreshTokenAccount)
    }

    static func loadRefreshToken() -> String? {
        load(account: refreshTokenAccount)
    }

    static func deleteRefreshToken() {
        delete(account: refreshTokenAccount)
    }

    // MARK: - Clear All

    static func deleteAll() {
        deleteToken()
        deleteRefreshToken()
    }

    // MARK: - Private

    private static func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
