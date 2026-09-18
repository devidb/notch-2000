//
//  Keychain.swift
//  Notch2000
//
//  Lecture des identifiants OAuth déposés par Claude Code dans le trousseau.
//

import Foundation
import Security

/// Identifiants OAuth tels que Claude Code les stocke dans le trousseau macOS.
struct ClaudeCredentials {
    let accessToken: String
    let expiresAt: Date?
    let subscriptionType: String?

    var isExpired: Bool { expires(within: 0) }

    /// Vrai si le jeton expire dans moins de `margin` secondes.
    func expires(within margin: TimeInterval) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSinceNow <= margin
    }
}

enum KeychainError: LocalizedError {
    /// Aucun élément : Claude Code n'est pas installé, ou aucune session n'est ouverte.
    case notFound
    /// L'utilisateur a refusé le dialogue d'accès au trousseau.
    case accessDenied
    case unexpectedFormat
    case other(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notFound:
            String(localized: "Aucune session Claude Code trouvée dans le trousseau.")
        case .accessDenied:
            String(localized: "L'accès au trousseau a été refusé.")
        case .unexpectedFormat:
            String(localized: "Les identifiants Claude Code sont dans un format inattendu.")
        case let .other(status):
            String(localized: "Erreur du trousseau (code \(status)).")
        }
    }
}

enum Keychain {
    /// Nom du service utilisé par Claude Code pour son élément de trousseau.
    private static let service = "Claude Code-credentials"

    /// Lit les identifiants OAuth de Claude Code.
    ///
    /// Le premier appel déclenche le dialogue d'autorisation du trousseau, puisque
    /// l'élément appartient à une autre application.
    static func claudeCredentials() throws -> ClaudeCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw KeychainError.notFound
        case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed:
            throw KeychainError.accessDenied
        default:
            throw KeychainError.other(status)
        }

        guard let data = item as? Data else { throw KeychainError.unexpectedFormat }
        return try parse(data)
    }

    private static func parse(_ data: Data) throws -> ClaudeCredentials {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String,
            !token.isEmpty
        else {
            throw KeychainError.unexpectedFormat
        }

        // `expiresAt` est un horodatage en millisecondes.
        var expiry: Date?
        if let millis = oauth["expiresAt"] as? Double, millis > 0 {
            expiry = Date(timeIntervalSince1970: millis / 1000)
        }

        return ClaudeCredentials(
            accessToken: token,
            expiresAt: expiry,
            subscriptionType: oauth["subscriptionType"] as? String
        )
    }
}
