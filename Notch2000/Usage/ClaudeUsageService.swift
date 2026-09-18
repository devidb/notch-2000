//
//  ClaudeUsageService.swift
//  Notch2000
//
//  Interrogation de l'API d'utilisation OAuth d'Anthropic.
//

import Foundation

/// Instantané de la fenêtre de session de 5 heures.
struct UsageSnapshot: Equatable {
    /// Pourcentage consommé, de 0 à 100.
    let percent: Double
    /// Instant où le quota se renouvelle.
    let resetsAt: Date?
}

enum UsageError: LocalizedError {
    case notAuthenticated(String)
    case rateLimited(retryAfter: TimeInterval)
    case unauthorized
    case server(Int)
    case malformed
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case let .notAuthenticated(reason):
            reason
        case .rateLimited:
            String(localized: "Trop de requêtes, nouvelle tentative dans un instant.")
        case .unauthorized:
            String(localized: "La session Claude Code a expiré. Reconnectez-vous avec `claude`.")
        case let .server(code):
            String(localized: "Le service a répondu \(code).")
        case .malformed:
            String(localized: "Réponse inattendue du service d'utilisation.")
        case let .transport(error):
            error.localizedDescription
        }
    }
}

/// Durée de la fenêtre de session Claude.
let sessionWindow: TimeInterval = 5 * 60 * 60

actor ClaudeUsageService {
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    /// L'en-tête `User-Agent` est obligatoire : sans lui, l'API applique une limite
    /// de débit très agressive et répond systématiquement 429.
    private let userAgent = "claude-code/2.1.236"

    private let session: URLSession

    /// Identifiants gardés en mémoire pour la durée de vie du jeton.
    ///
    /// L'élément de trousseau appartient à Claude Code : chaque lecture peut faire
    /// apparaître le dialogue d'autorisation de macOS. On n'y retourne donc qu'à
    /// l'expiration du jeton ou quand l'API le refuse, pas à chaque rafraîchissement.
    private var cached: ClaudeCredentials?

    /// Marge avant expiration en deçà de laquelle on relit le trousseau.
    private let expiryMargin: TimeInterval = 60

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    /// Le quota, et d'où venaient les identifiants qui ont permis de le lire.
    func fetch() async throws -> (UsageSnapshot, CredentialSource?) {
        if let fake = Self.debugSnapshot() { return (fake, nil) }

        let (credentials, fromCache) = try loadCredentials()
        do {
            return (try await fetchUsage(using: credentials), credentials.source)
        } catch UsageError.unauthorized where fromCache {
            // Claude Code a pu renouveler le jeton depuis notre dernière lecture :
            // une seule relecture du dépôt, puis on abandonne pour ce tour.
            cached = nil
            let (fresh, _) = try loadCredentials()
            return (try await fetchUsage(using: fresh), fresh.source)
        }
    }

    /// Oublie les identifiants gardés en mémoire : la prochaine lecture
    /// retourne au dépôt, donc macOS repose sa question d'autorisation.
    func forgetCredentials() {
        cached = nil
    }

    /// Renvoie les identifiants, en relisant leur dépôt seulement si nécessaire.
    private func loadCredentials() throws -> (ClaudeCredentials, fromCache: Bool) {
        if let cached, !cached.expires(within: expiryMargin) { return (cached, true) }

        cached = nil

        // Seuls les identifiants OAuth de la session conviennent. Un jeton de
        // longue durée déclaré dans les réglages de Claude Code
        // (`env.CLAUDE_CODE_OAUTH_TOKEN`) ne ferait pas l'affaire : il ne porte
        // que le droit d'inférence, et l'API d'utilisation le rejette faute de
        // la portée `user:profile`.
        let fresh: ClaudeCredentials
        do {
            fresh = try ClaudeCredentialStore.load()
        } catch {
            throw UsageError.notAuthenticated(error.localizedDescription)
        }

        guard !fresh.isExpired else { throw UsageError.unauthorized }
        cached = fresh
        return (fresh, false)
    }

    private func fetchUsage(using credentials: ClaudeCredentials) async throws -> UsageSnapshot {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw UsageError.malformed }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw UsageError.unauthorized
        case 429:
            let header = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            // Plancher volontairement haut : l'API tolère mal les interrogations rapprochées.
            throw UsageError.rateLimited(retryAfter: max(header ?? 0, 180))
        default:
            throw UsageError.server(http.statusCode)
        }

        guard let snapshot = Self.parse(data) else { throw UsageError.malformed }
        return snapshot
    }

    // MARK: - Décodage

    /// Décode la fenêtre de 5 heures en tolérant les variations de nommage du service.
    static func parse(_ data: Data) -> UsageSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let window = firstDictionary(in: root, keys: ["five_hour", "fiveHour", "5h"]) ?? root

        guard let percent = firstNumber(
            in: window,
            keys: ["utilization", "used_percent", "usedPercent", "percentage", "percent"]
        ) else { return nil }

        let resets = firstDate(
            in: window,
            keys: ["resets_at", "resetsAt", "reset_at", "resetAt", "resets"]
        )

        return UsageSnapshot(percent: min(max(percent, 0), 100), resetsAt: resets)
    }

    private static func firstDictionary(in root: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys {
            if let value = root[key] as? [String: Any] { return value }
        }
        return nil
    }

    private static func firstNumber(in root: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = root[key] as? Double { return value }
            if let value = root[key] as? Int { return Double(value) }
            if let text = root[key] as? String, let value = Double(text) { return value }
        }
        return nil
    }

    private static func firstDate(in root: [String: Any], keys: [String]) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()

        for key in keys {
            if let text = root[key] as? String {
                if let date = formatter.date(from: text) ?? plain.date(from: text) { return date }
            }
            // Certaines variantes renvoient un horodatage Unix, en secondes ou en millisecondes.
            if let number = root[key] as? Double, number > 0 {
                return Date(timeIntervalSince1970: number > 1e11 ? number / 1000 : number)
            }
            if let number = root[key] as? Int, number > 0 {
                let value = Double(number)
                return Date(timeIntervalSince1970: value > 1e11 ? value / 1000 : value)
            }
        }
        return nil
    }

    // MARK: - Aide au développement

    /// Permet de forcer un état sans consommer l'API : `N2K_FAKE_PCT=88 N2K_FAKE_RESET_MIN=36`.
    private static func debugSnapshot() -> UsageSnapshot? {
        let environment = ProcessInfo.processInfo.environment
        guard let raw = environment["N2K_FAKE_PCT"], let percent = Double(raw) else { return nil }
        let minutes = Double(environment["N2K_FAKE_RESET_MIN"] ?? "") ?? 114
        return UsageSnapshot(
            percent: min(max(percent, 0), 100),
            resetsAt: Date().addingTimeInterval(minutes * 60)
        )
    }
}
