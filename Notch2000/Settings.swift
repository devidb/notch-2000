//
//  Settings.swift
//  Notch2000
//
//  Réglages persistés, partagés par le notch et la fenêtre de réglages.
//

import Combine
import Foundation
import ServiceManagement

/// Ce que montre la valeur de droite : l'heure du renouvellement, ou le temps restant.
enum RenewalDisplay: String, Codable, CaseIterable, Identifiable {
    case target
    case countdown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .target: String(localized: "Heure cible")
        case .countdown: String(localized: "Compte à rebours")
        }
    }
}

/// Ce qui gouverne la couleur de la barre.
enum BarPalette: String, Codable, CaseIterable, Identifiable {
    /// L'orange de Claude, quel que soit le niveau.
    case claude
    /// Menthe, ambre puis braise selon ce qui a été consommé.
    case consumption

    var id: String { rawValue }
}

/// Dessin de la jauge : le trait lumineux, ou une rangée de carrés.
enum BarStyle: String, Codable, CaseIterable, Identifiable {
    case line
    case dots

    var id: String { rawValue }
}

/// Intensité du halo autour de la barre.
enum GlowIntensity: String, Codable, CaseIterable, Identifiable {
    case soft
    case strong

    var id: String { rawValue }

    /// Facteur appliqué aux rayons et aux opacités des lueurs.
    var scale: Double {
        switch self {
        case .soft: 0.45
        case .strong: 1
        }
    }
}

@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    /// Repère du temps écoulé posé sur la barre.
    @PublishedPersist(key: "kittEnabled", defaultValue: true)
    var kittEnabled: Bool

    /// Chiffres affichés en permanence, plutôt qu'au seul survol.
    @PublishedPersist(key: "digitsAlwaysVisible", defaultValue: false)
    var digitsAlwaysVisible: Bool

    @PublishedPersist(key: "renewalDisplay", defaultValue: RenewalDisplay.target)
    var renewalDisplay: RenewalDisplay

    @PublishedPersist(key: "barPalette", defaultValue: BarPalette.claude)
    var barPalette: BarPalette

    @PublishedPersist(key: "barStyle", defaultValue: BarStyle.line)
    var barStyle: BarStyle

    @PublishedPersist(key: "glowIntensity", defaultValue: GlowIntensity.strong)
    var glowIntensity: GlowIntensity

    /// Trait et repère poussés au delà du blanc SDR, sur les écrans HDR.
    @PublishedPersist(key: "hdrEnabled", defaultValue: true)
    var hdrEnabled: Bool

    private init() {}

    // MARK: - Ouverture à la connexion

    /// Ouverture à la connexion, publiée comme les autres réglages.
    ///
    /// `SMAppService` est un service système : il répond de façon asynchrone et
    /// ne prévient personne quand son état change. Le modèle en garde donc une
    /// copie publiée, que la vue lit comme n'importe quel autre réglage, et qui
    /// est resynchronisée après chaque écriture et à chaque ouverture du panneau.
    @Published var launchAtLogin: Bool = Settings.registeredForLogin {
        didSet {
            guard !isSyncingLaunchAtLogin, launchAtLogin != oldValue else { return }
            applyLaunchAtLogin()
        }
    }

    /// Vrai le temps de recopier l'état du système : la copie ne doit pas
    /// relancer un enregistrement.
    private var isSyncingLaunchAtLogin = false

    private static var registeredForLogin: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: true
        default: false
        }
    }

    /// Relit l'état du système, par exemple après un passage par les Réglages.
    func refreshLaunchAtLogin() {
        isSyncingLaunchAtLogin = true
        launchAtLogin = Self.registeredForLogin
        isSyncingLaunchAtLogin = false
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Notch2000: ouverture à la connexion impossible: \(error.localizedDescription)")
        }
        // macOS met un instant à répercuter l'écriture ; si elle a échoué, la
        // touche revient d'elle même à l'état réel.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.refreshLaunchAtLogin()
        }
    }

    /// L'ouverture est enregistrée mais attend le feu vert de l'utilisateur.
    var launchAtLoginNeedsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Ouvre le volet des ouvertures automatiques des Réglages Système.
    func revealLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
