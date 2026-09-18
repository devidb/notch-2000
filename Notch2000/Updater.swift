//
//  Updater.swift
//  Notch2000
//
//  Mises à jour automatiques via Sparkle, avec ses fenêtres standard.
//
//  Sparkle vérifie au lancement puis à l'intervalle déclaré dans Info.plist, et
//  présente lui-même ce qu'il trouve. Une mise à jour ne revient que quelques
//  fois par an : elle ne mérite ni touche ni écran dans le notch.
//
//  Sparkle n'est résolu que par la chaîne Xcode, jamais par `Scripts/build.sh`
//  qui compile sans gestionnaire de paquets. Tout est donc conditionné à sa
//  présence : le script continue de produire une app complète, simplement sans
//  recherche de mise à jour.
//

import AppKit

#if canImport(Sparkle)
    import Sparkle

    final class Updater: NSObject, SPUStandardUserDriverDelegate {
        static let shared = Updater()

        private var controller: SPUStandardUpdaterController!

        override private init() {
            super.init()
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: self
            )
        }

        // MARK: - SPUStandardUserDriverDelegate

        // Notch2000 n'a ni icône dans le Dock ni fenêtre au premier plan : une
        // fenêtre de mise à jour ouverte en arrière-plan passerait inaperçue.
        // Sparkle demande alors aux apps d'agent de gérer ce rappel elles-mêmes.
        var supportsGentleScheduledUpdateReminders: Bool { true }

        /// Une mise à jour trouvée en tâche de fond est ramenée au premier plan.
        func standardUserDriverWillHandleShowingUpdate(
            _ handleShowingUpdate: Bool,
            forUpdate _: SUAppcastItem,
            state: SPUUserUpdateState
        ) {
            guard handleShowingUpdate, !state.userInitiated else { return }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

#else

    /// L'app a été bâtie sans Sparkle : pas de recherche de mise à jour.
    final class Updater {
        static let shared = Updater()

        private init() {}
    }

#endif
