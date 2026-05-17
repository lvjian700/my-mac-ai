import Foundation
@preconcurrency import Security

public enum KeychainStoreError: LocalizedError, Equatable {
    case unhandledStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

public protocol APIKeyStore: Sendable {
    func readAPIKey() -> String?
    func writeAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}

public struct AnthropicAPIKeyStore: APIKeyStore {
    private let service = "ai.my-mac.ical-mac"
    private let account = "anthropic-api-key"

    public init() {}

    public func readAPIKey() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        }
        return String(data: data, encoding: .utf8)
    }

    public func writeAPIKey(_ key: String) throws {
        try deleteAPIKey(allowMissing: true)
        var item = baseQuery()
        item[kSecValueData as String] = Data(key.utf8)
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    public func deleteAPIKey() throws {
        try deleteAPIKey(allowMissing: true)
    }

    private func deleteAPIKey(allowMissing: Bool) throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || (allowMissing && status == errSecItemNotFound) else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
