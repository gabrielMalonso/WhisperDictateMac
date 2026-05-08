import Foundation
import Security

enum GroqCredentialStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return String(localized: "Keychain retornou erro \(status).")
        case .invalidData:
            return String(localized: "A chave salva no Keychain não pôde ser lida.")
        }
    }
}

protocol GroqCredentialStoring {
    func apiKey() throws -> String?
    func save(apiKey: String) throws
    func deleteAPIKey() throws
}

struct GroqCredentialStore: GroqCredentialStoring {
    private let service = "\(AppConfig.appBundleId).groq"
    private let account = "api-key"

    func apiKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw GroqCredentialStoreError.unexpectedStatus(status)
        }
        guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            throw GroqCredentialStoreError.invalidData
        }
        return key
    }

    func save(apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteAPIKey()
            return
        }

        let data = Data(trimmed.utf8)
        var query = baseQuery()
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw GroqCredentialStoreError.unexpectedStatus(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw GroqCredentialStoreError.unexpectedStatus(addStatus)
        }
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw GroqCredentialStoreError.unexpectedStatus(status)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
