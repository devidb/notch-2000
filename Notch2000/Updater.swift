//
//  Updater.swift
//  Notch2000
//
//  Mises à jour automatiques via Sparkle, rendues dans le notch.
//
//  Sparkle sait présenter lui-même ses fenêtres, mais elles s'ouvrent au centre
//  de l'écran, sous un panneau déplié qui occupe déjà le haut : on ne voit plus
//  rien et on ne peut plus replier. On lui fournit donc notre propre pilote
//  d'interface (`SPUUserDriver`) : Sparkle décrit ce qu'il se passe, le notch
//  l'affiche, l'utilisateur répond depuis le panneau.
//
//  Sparkle n'est résolu que par la chaîne Xcode, jamais par `Scripts/build.sh`
//  qui compile sans gestionnaire de paquets. Tout est donc conditionné à sa
//  présence : le script continue de produire une app complète, simplement sans
//  recherche de mise à jour.
//

import SwiftUI

/// Ce que le panneau doit montrer de la mise à jour en cours.
enum UpdateStage: Equatable {
    /// Rien en cours : le panneau garde ses réglages.
    case idle
    case checking
    case found(version: String)
    /// `nil` tant que la taille attendue est inconnue.
    case downloading(fraction: Double?)
    case preparing(fraction: Double)
    case readyToRelaunch(version: String)
    case installing
    case upToDate
    case failed(String)

    var isPresenting: Bool { self != .idle }
}

extension Notification.Name {
    /// Demande au notch de se déplier, quand Sparkle a quelque chose à montrer.
    static let notchShouldOpen = Notification.Name("app.notch2000.notchShouldOpen")
}

#if canImport(Sparkle)
    import Sparkle

    @MainActor
    final class Updater: NSObject, ObservableObject, SPUUserDriver {
        static let shared = Updater()

        /// Disponible dès que Sparkle est compilé dans l'app.
        static let isAvailable = true

        @Published private(set) var stage: UpdateStage = .idle

        private var updater: SPUUpdater!

        /// Réponses attendues par Sparkle, gardées le temps que l'utilisateur décide.
        private var choiceReply: ((SPUUserUpdateChoice) -> Void)?
        private var acknowledgement: (() -> Void)?
        private var cancellation: (() -> Void)?

        /// Octets annoncés puis reçus, pour donner une fraction à la barre.
        private var expectedLength: UInt64 = 0
        private var receivedLength: UInt64 = 0

        override private init() {
            super.init()
            updater = SPUUpdater(
                hostBundle: .main,
                applicationBundle: .main,
                userDriver: self,
                delegate: nil
            )
            do {
                // Démarre le programmateur : l'intervalle vient d'Info.plist.
                try updater.start()
            } catch {
                NSLog("Notch2000: Sparkle n'a pas démarré: \(error.localizedDescription)")
            }
        }

        // MARK: - Commandes du panneau

        func checkForUpdates() {
            updater.checkForUpdates()
        }

        /// Installer, ou relancer une fois l'installation préparée.
        func install() { reply(.install) }

        /// Remettre à plus tard : Sparkle reproposera la version.
        func later() { reply(.dismiss) }

        /// Refermer un message qui n'attend qu'un acquittement, ou annuler ce qui est en cours.
        func dismiss() {
            if let acknowledgement {
                self.acknowledgement = nil
                stage = .idle
                acknowledgement()
                return
            }
            if let cancellation {
                self.cancellation = nil
                stage = .idle
                cancellation()
                return
            }
            if choiceReply != nil {
                later()
                return
            }
            stage = .idle
        }

        private func reply(_ choice: SPUUserUpdateChoice) {
            guard let choiceReply else { return }
            self.choiceReply = nil
            if choice != .install { stage = .idle }
            choiceReply(choice)
        }

        /// Déplie le notch : sans cela, une vérification programmée n'aurait
        /// nulle part où s'afficher.
        private func requestFocus() {
            NotificationCenter.default.post(name: .notchShouldOpen, object: nil)
        }

        private func forget() {
            choiceReply = nil
            acknowledgement = nil
            cancellation = nil
            expectedLength = 0
            receivedLength = 0
        }

        // MARK: - SPUUserDriver

        func show(
            _: SPUUpdatePermissionRequest,
            reply: @escaping (SUUpdatePermissionResponse) -> Void
        ) {
            // Les vérifications automatiques sont déclarées dans Info.plist :
            // il n'y a pas de question à poser à l'utilisateur.
            reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
        }

        func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
            stage = .checking
        }

        func showUpdateFound(
            with appcastItem: SUAppcastItem,
            state: SPUUserUpdateState,
            reply: @escaping (SPUUserUpdateChoice) -> Void
        ) {
            cancellation = nil
            choiceReply = reply
            let version = appcastItem.displayVersionString
            stage = state.stage == .installing
                ? .readyToRelaunch(version: version)
                : .found(version: version)
            requestFocus()
        }

        func showUpdateReleaseNotes(with _: SPUDownloadData) {
            // Les notes de version n'ont pas leur place dans un panneau de 340 points.
        }

        func showUpdateReleaseNotesFailedToDownloadWithError(_: any Error) {}

        func showUpdateNotFoundWithError(_: any Error, acknowledgement: @escaping () -> Void) {
            // L'erreur ne fait que redire « aucune version plus récente » :
            // le panneau annonce simplement que l'app est à jour.
            cancellation = nil
            self.acknowledgement = acknowledgement
            stage = .upToDate
        }

        func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
            cancellation = nil
            self.acknowledgement = acknowledgement
            stage = .failed(error.localizedDescription)
            requestFocus()
        }

        func showDownloadInitiated(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
            expectedLength = 0
            receivedLength = 0
            stage = .downloading(fraction: nil)
        }

        func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
            expectedLength = expectedContentLength
            receivedLength = 0
        }

        func showDownloadDidReceiveData(ofLength length: UInt64) {
            receivedLength += length
            guard expectedLength > 0 else { return }
            let fraction = min(Double(receivedLength) / Double(expectedLength), 1)
            stage = .downloading(fraction: fraction)
        }

        func showDownloadDidStartExtractingUpdate() {
            cancellation = nil
            stage = .preparing(fraction: 0)
        }

        func showExtractionReceivedProgress(_ progress: Double) {
            stage = .preparing(fraction: min(max(progress, 0), 1))
        }

        func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
            choiceReply = reply
            stage = .readyToRelaunch(version: appVersionAvailable)
            requestFocus()
        }

        func showInstallingUpdate(
            withApplicationTerminated _: Bool,
            retryTerminatingApplication _: @escaping () -> Void
        ) {
            stage = .installing
        }

        func showUpdateInstalledAndRelaunched(
            _: Bool,
            acknowledgement: @escaping () -> Void
        ) {
            stage = .idle
            acknowledgement()
        }

        func showUpdateInFocus() {
            requestFocus()
        }

        func dismissUpdateInstallation() {
            forget()
            stage = .idle
        }

        /// Version proposée, quand Sparkle ne la redonne pas au moment de relancer.
        private var appVersionAvailable: String {
            if case let .found(version) = stage { return version }
            if case let .readyToRelaunch(version) = stage { return version }
            return ""
        }
    }

#else

    @MainActor
    final class Updater: ObservableObject {
        static let shared = Updater()

        /// L'app a été bâtie sans Sparkle : la recherche de mise à jour est masquée.
        static let isAvailable = false

        @Published private(set) var stage: UpdateStage = .idle

        private init() {}

        func checkForUpdates() {}
        func install() {}
        func later() {}
        func dismiss() {}
    }

#endif
