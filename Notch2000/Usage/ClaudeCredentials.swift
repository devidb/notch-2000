//
//  ClaudeCredentials.swift
//  Notch2000
//
//  Lecture des identifiants OAuth déposés par Claude Code.
//
//  Claude Code a deux dépôts possibles : le trousseau macOS, son choix par
//  défaut, et un fichier `~/.claude/.credentials.json` sur lequel il retombe
//  quand le trousseau n'est pas disponible (session distante, connexion depuis
//  un terminal sans accès à l'agent de sécurité, `claude setup-token`). On lit
//  les deux, sinon une machine parfaitement connectée paraît déconnectée.
//

import Foundation
import Security

/// D'où viennent les identifiants, pour pouvoir le dire dans le panneau.
enum CredentialSource: String {
    case keychain
    case file

    var label: String {
        switch self {
        case .keychain: String(localized: "trousseau")
        case .file: String(localized: "fichier de session")
        }
    }
}

/// Identifiants OAuth tels que Claude Code les dépose.
struct ClaudeCredentials {
    let accessToken: String
    let expiresAt: Date?
    let subscriptionType: String?
    let source: CredentialSource

    var isExpired: Bool { expires(within: 0) }

    /// Vrai si le jeton expire dans moins de `margin` secondes.
    func expires(within margin: TimeInterval) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSinceNow <= margin
    }
}

/// Les refus du trousseau ne se soignent pas tous de la même façon : tant que
/// le panneau ne disait que « Déconnecté », rien ne permettait de les départager.
enum CredentialsError: LocalizedError {
    /// Ni trousseau ni fichier : Claude Code n'est pas installé, ou aucune session n'est ouverte.
    case missing
    /// L'utilisateur a fermé le dialogue d'autorisation sans accepter.
    case userRefused
    /// L'élément existe mais Notch2000 n'est pas sur sa liste de contrôle d'accès.
    case notAuthorized
    /// Trousseau verrouillé, ou macOS a refusé d'afficher le dialogue : c'est le
    /// cas qui se manifeste par un silence complet, sans la moindre fenêtre.
    case noInteraction
    /// Un dépôt existe mais ne contient pas ce qu'on attend.
    case unexpectedFormat(CredentialSource)
    /// Le trousseau a répondu autre chose que « trouvé » ou « absent ».
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missing:
            return String(localized: "Aucune session Claude Code sur ce Mac. Lancez `claude` dans un terminal, connectez-vous, puis actualisez.")
        case .userRefused:
            return String(localized: "Vous avez refusé l'accès au trousseau. Actualisez pour que macOS repose la question.")
        case .notAuthorized:
            return String(localized: "Notch2000 n'est pas autorisé à lire « Claude Code-credentials ». Trousseau d'accès, double-clic sur l'élément, onglet Contrôle d'accès, ajoutez Notch2000.")
        case .noInteraction:
            return String(localized: "Trousseau verrouillé ou dialogue bloqué. Ouvrez Trousseau d'accès et déverrouillez « Connexion », puis actualisez.")
        case let .unexpectedFormat(source):
            return String(localized: "Identifiants Claude Code illisibles (\(source.label)). Reconnectez-vous avec `claude`.")
        case let .keychain(status):
            // Le libellé du Security framework en dit plus que le code seul.
            // Le code passe par une chaîne : interpolé tel quel, le format de la
            // clé localisée dépendrait de la largeur d'`OSStatus`.
            let code = String(status)
            guard let detail = SecCopyErrorMessageString(status, nil) as String? else {
                return String(localized: "Trousseau inaccessible (code \(code)).")
            }
            return String(localized: "Trousseau inaccessible (code \(code)) : \(detail)")
        }
    }

    /// L'élément est là, mais sa lecture a été refusée. Le repli par fichier
    /// n'aurait alors aucun sens : il masquerait la seule piste utile.
    var isRefusal: Bool {
        switch self {
        case .userRefused, .notAuthorized, .noInteraction: true
        default: false
        }
    }
}

enum ClaudeCredentialStore {
    /// Nom du service utilisé par Claude Code pour son élément de trousseau.
    static let keychainService = "Claude Code-credentials"

    /// Lit les identifiants, trousseau d'abord puis fichier.
    ///
    /// La première lecture du trousseau déclenche le dialogue d'autorisation de
    /// macOS, puisque l'élément appartient à une autre application.
    static func load() throws -> ClaudeCredentials {
        switch fromKeychain() {
        case let .success(credentials):
            return credentials

        case let .failure(keychainError):
            // Doublé dans le journal système : sur une machine où le panneau ne
            // s'ouvre pas, `log show --predicate 'process == "Notch2000"'`
            // reste le seul moyen de savoir ce que le trousseau a répondu.
            NSLog("Notch2000: trousseau: %@", keychainError.localizedDescription)

            // Un refus explicite mérite d'être dit tel quel : aller chercher
            // ensuite un fichier masquerait la vraie raison du silence.
            if keychainError.isRefusal { throw keychainError }

            switch fromFile() {
            case let .success(credentials):
                return credentials
            case .failure(.missing):
                // Le fichier n'est qu'un repli : absent, c'est le diagnostic du
                // trousseau qui décrit le mieux la situation.
                throw keychainError
            case let .failure(fileError):
                throw fileError
            }
        }
    }

    // MARK: - Trousseau

    private static func fromKeychain() -> Result<ClaudeCredentials, CredentialsError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            return .failure(.missing)
        case errSecUserCanceled:
            return .failure(.userRefused)
        case errSecAuthFailed:
            return .failure(.notAuthorized)
        case errSecInteractionNotAllowed, errSecInteractionRequired:
            return .failure(.noInteraction)
        default:
            return .failure(.keychain(status))
        }

        guard let data = item as? Data else { return .failure(.unexpectedFormat(.keychain)) }
        return parse(data, from: .keychain)
    }

    // MARK: - Fichier

    /// Dossier de configuration de Claude Code, `CLAUDE_CONFIG_DIR` compris.
    static var configDirectory: URL {
        let environment = ProcessInfo.processInfo.environment
        if let custom = environment["CLAUDE_CONFIG_DIR"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    private static var credentialsFile: URL {
        configDirectory.appendingPathComponent(".credentials.json")
    }

    private static func fromFile() -> Result<ClaudeCredentials, CredentialsError> {
        guard let data = try? Data(contentsOf: credentialsFile) else { return .failure(.missing) }
        return parse(data, from: .file)
    }

    // MARK: - Décodage

    /// Les deux dépôts portent la même charge utile.
    private static func parse(
        _ data: Data,
        from source: CredentialSource
    ) -> Result<ClaudeCredentials, CredentialsError> {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String,
            !token.isEmpty
        else {
            return .failure(.unexpectedFormat(source))
        }

        // `expiresAt` est un horodatage en millisecondes.
        var expiry: Date?
        if let millis = oauth["expiresAt"] as? Double, millis > 0 {
            expiry = Date(timeIntervalSince1970: millis / 1000)
        }

        return .success(ClaudeCredentials(
            accessToken: token,
            expiresAt: expiry,
            subscriptionType: oauth["subscriptionType"] as? String,
            source: source
        ))
    }
}
