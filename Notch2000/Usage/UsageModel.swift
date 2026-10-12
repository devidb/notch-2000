//
//  UsageModel.swift
//  Notch2000
//
//  État du quota de session affiché par le notch.
//

import Combine
import Foundation

@MainActor
final class UsageModel: ObservableObject {
    enum State: Equatable {
        /// Aucune valeur encore lue : le notch joue le balayage de synchronisation.
        case syncing
        case live(UsageSnapshot)
        /// Pas de session utilisable ; le motif est montré dans les réglages.
        case unavailable(String)
    }

    @Published private(set) var state: State = .syncing {
        didSet { updateScanActivity() }
    }
    /// Dépôt d'où sont venus les derniers identifiants utilisés, montré au pied du panneau.
    @Published private(set) var credentialSource: CredentialSource?
    /// Pourcentage forcé pour prévisualiser les couleurs. `nil` = valeur réelle.
    @Published private(set) var previewPercent: Double?
    /// Minutes restantes forcées avant le renouvellement. `nil` = valeur réelle.
    @Published private(set) var previewRemainingMinutes: Double?
    /// Recalculé périodiquement pour faire vivre le compte à rebours et le repère de temps.
    @Published private(set) var now: Date = .init()

    private let service = ClaudeUsageService()
    private var refreshTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var scanActivity: NSObjectProtocol?

    /// Intervalle demandé par l'utilisateur, en secondes.
    var refreshInterval: TimeInterval = 60 {
        didSet { if refreshInterval != oldValue { restart() } }
    }

    init(refreshInterval: TimeInterval = 60) {
        self.refreshInterval = refreshInterval
    }

    /// Modèle figé, pour les rendus hors écran qui vérifient la mise en page.
    init(preview state: State) {
        self.state = state
    }

    deinit {
        refreshTask?.cancel()
        tickTask?.cancel()
    }

    // MARK: - Cycle de vie

    func start() {
        guard refreshTask == nil else { return }

        // L'état de départ est déjà `syncing` : `didSet` ne se déclenche pas.
        updateScanActivity()

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let wait = await self.refreshOnce()
                try? await Task.sleep(for: .seconds(wait))
            }
        }

        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self else { return }
                await MainActor.run { self.now = Date() }
            }
        }
    }

    private func restart() {
        refreshTask?.cancel()
        refreshTask = nil
        tickTask?.cancel()
        tickTask = nil
        start()
    }

    /// Effectue une lecture et renvoie le délai à respecter avant la suivante.
    @discardableResult
    private func refreshOnce() async -> TimeInterval {
        // Aide au développement : retient le balayage, sinon inatteignable sans
        // se déconnecter de Claude Code. Le test est ici et non au démarrage de
        // la boucle, parce qu'ouvrir le panneau relit le quota de son côté.
        if ProcessInfo.processInfo.environment["N2K_FAKE_SYNCING"] == "1" {
            state = .syncing
            return 3600
        }

        do {
            let (snapshot, source) = try await service.fetch()
            state = .live(snapshot)
            credentialSource = source
            now = Date()
            return refreshInterval
        } catch let error as UsageError {
            if case let .rateLimited(retryAfter) = error {
                // On conserve la dernière valeur connue plutôt que d'afficher une erreur.
                return max(retryAfter, refreshInterval)
            }
            if case .transport = error, case .live = state {
                // Coupure réseau passagère : la valeur précédente reste pertinente.
                return refreshInterval
            }
            state = .unavailable(error.localizedDescription)
            credentialSource = nil
            return max(refreshInterval, 60)
        } catch {
            state = .unavailable(error.localizedDescription)
            credentialSource = nil
            return max(refreshInterval, 60)
        }
    }

    func refreshNow() {
        Task { await refreshOnce() }
    }

    /// App Nap suspend le rendu d'une app accessoire qui n'a pas le focus : au
    /// bout de quelques secondes, le balayage se fige en pleine course. Tant
    /// qu'il tourne, on déclare donc une activité. Elle laisse le Mac s'endormir
    /// normalement : seule la mise en sommeil de l'app est écartée.
    private func updateScanActivity() {
        if isSyncing, scanActivity == nil {
            scanActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Balayage de synchronisation"
            )
        } else if !isSyncing, let scanActivity {
            ProcessInfo.processInfo.endActivity(scanActivity)
            self.scanActivity = nil
        }
    }

    /// Oublie le jeton en mémoire et relit le dépôt : macOS redemande alors
    /// l'accès au trousseau, ce qui permet de réparer un refus d'autorisation.
    func reauthenticate() {
        state = .syncing
        Task {
            await service.forgetCredentials()
            await refreshOnce()
        }
    }

    // MARK: - Valeurs dérivées

    var snapshot: UsageSnapshot? {
        if case let .live(snapshot) = state { return snapshot }
        return nil
    }

    var isSyncing: Bool {
        // Un aperçu doit s'afficher même si le quota réel n'a pas encore été lu.
        if previewPercent != nil { return false }
        if case .live = state { return false }
        return true
    }

    var percent: Double { previewPercent ?? snapshot?.percent ?? 0 }

    /// Force un pourcentage depuis la fenêtre de développement. `nil` = valeur réelle.
    func setPreviewPercent(_ value: Double?) {
        previewPercent = value
    }

    /// Force le temps restant avant renouvellement, depuis la fenêtre de développement.
    func setPreviewRemainingMinutes(_ value: Double?) {
        previewRemainingMinutes = value
    }

    /// Heure du renouvellement, aperçu compris.
    var resetsAt: Date? {
        if let minutes = previewRemainingMinutes { return now.addingTimeInterval(minutes * 60) }
        return snapshot?.resetsAt
    }

    /// Fait défiler les trois paliers de couleur, puis revient au quota réel.
    func cyclePreview() {
        switch previewPercent {
        case nil: previewPercent = 35
        case 35: previewPercent = 65
        case 65: previewPercent = 92
        default: previewPercent = nil
        }
    }

    /// Remplissage de la barre, de 0 à 1.
    var fillFraction: Double { min(max(percent / 100, 0), 1) }

    var isAlert: Bool { !isSyncing && percent >= Theme.alertThreshold && percent < 100 }

    var isAtLimit: Bool { !isSyncing && percent >= 100 }

    /// Position du repère KITT : part de la fenêtre de 5 heures déjà écoulée.
    var elapsedFraction: Double? {
        guard let resetsAt else { return nil }
        let remaining = resetsAt.timeIntervalSince(now)
        guard remaining > 0 else { return 1 }
        return min(max(1 - remaining / sessionWindow, 0), 1)
    }

    /// Vide tant qu'il n'y a rien à dire : des pointillés à la place d'un chiffre
    /// se lisent comme une valeur, alors que le balayage dit déjà l'attente.
    var percentLabel: String {
        isSyncing ? "" : "\(Int(percent.rounded()))%"
    }

    /// Libellé de renouvellement, selon le réglage choisi.
    func renewalLabel(_ display: RenewalDisplay) -> String {
        guard !isSyncing, let resetsAt else { return "" }

        switch display {
        case .target:
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.setLocalizedDateFormatFromTemplate("Hm")
            return formatter.string(from: resetsAt)
        case .countdown:
            let remaining = max(resetsAt.timeIntervalSince(now), 0)
            let minutes = Int((remaining / 60).rounded(.up))
            return "\(minutes / 60)h\(String(format: "%02d", minutes % 60))"
        }
    }

    /// Phrase complète affichée sous le grand chiffre du panneau.
    func renewalSubtitle(_ display: RenewalDisplay) -> String {
        guard !isSyncing, resetsAt != nil else { return String(localized: "renouvellement inconnu") }
        switch display {
        case .target:
            return String(localized: "renouvellement dans \(renewalLabel(.countdown))")
        case .countdown:
            return String(localized: "renouvellement à \(renewalLabel(.target))")
        }
    }
}
