//
//  Updater.swift
//  Notch2000
//
//  Mises à jour automatiques via Sparkle.
//
//  Sparkle n'est résolu que par la chaîne Xcode, jamais par `Scripts/build.sh`
//  qui compile sans gestionnaire de paquets. Tout est donc conditionné à sa
//  présence : le script continue de produire une app complète, simplement sans
//  recherche de mise à jour.
//

import SwiftUI

#if canImport(Sparkle)
    import Sparkle

    @MainActor
    final class Updater: ObservableObject {
        static let shared = Updater()

        /// Disponible dès que Sparkle est compilé dans l'app.
        static let isAvailable = true

        private let controller: SPUStandardUpdaterController

        private init() {
            // `startingUpdater: true` laisse Sparkle planifier ses vérifications
            // selon l'intervalle déclaré dans Info.plist.
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }

        func checkForUpdates() {
            controller.updater.checkForUpdates()
        }
    }
#else
    @MainActor
    final class Updater: ObservableObject {
        static let shared = Updater()

        /// L'app a été bâtie sans Sparkle : la recherche de mise à jour est masquée.
        static let isAvailable = false

        private init() {}

        func checkForUpdates() {}
    }
#endif
