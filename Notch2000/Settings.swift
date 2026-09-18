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

/// Fréquence d'interrogation du service d'utilisation.
enum RefreshRate: Int, Codable, CaseIterable, Identifiable {
    case everyMinute = 60
    case everyFiveMinutes = 300

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .everyMinute: String(localized: "Toutes les minutes")
        case .everyFiveMinutes: String(localized: "Toutes les 5 minutes")
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

    @PublishedPersist(key: "glowIntensity", defaultValue: GlowIntensity.strong)
    var glowIntensity: GlowIntensity

    @PublishedPersist(key: "refreshRate", defaultValue: RefreshRate.everyMinute)
    var refreshRate: RefreshRate

    @PublishedPersist(key: "hapticFeedback", defaultValue: true)
    var hapticFeedback: Bool

    private init() {}

    // MARK: - Ouverture à la connexion

    /// Reflète l'état réel du service de démarrage plutôt qu'une copie persistée.
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Notch2000: ouverture à la connexion impossible: \(error.localizedDescription)")
            }
        }
    }
}
