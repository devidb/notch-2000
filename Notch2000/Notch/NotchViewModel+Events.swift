//
//  NotchViewModel+Events.swift
//  Notch2000
//
//  Dérivé de NotchDrop (MIT, Lakr Aream) : suivi global du pointeur et des clics.
//

import Cocoa
import Combine
import Foundation
import SwiftUI

extension NotchViewModel {
    func setupCancellables() {
        let events = EventMonitors.shared

        events.mouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let location = NSEvent.mouseLocation

                switch status {
                case .opened:
                    // Un clic sur le bandeau du notch referme, comme un second appui.
                    if hoverRect.contains(location) || openedHeadlineRect.contains(location) {
                        close()
                    } else if !openedRect.contains(location) {
                        close()
                    }
                case .closed, .hovered:
                    if hoverRect.contains(location) { open() }
                }
            }
            .store(in: &cancellables)

        events.mouseLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let location = NSEvent.mouseLocation

                switch status {
                case .closed:
                    if hoverRect.contains(location) { hover() }
                case .hovered:
                    if !activeHoverRect.contains(location) { unhover() }
                case .opened:
                    break
                }
            }
            .store(in: &cancellables)

        // Sparkle a quelque chose à montrer, et le notch est son seul écran :
        // sans cela, une vérification programmée n'aurait nulle part où parler.
        NotificationCenter.default.publisher(for: .notchShouldOpen)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.open() }
            .store(in: &cancellables)

        // Le retour haptique reste discret : au plus une impulsion par demi-seconde.
        hapticSender
            .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: false)
            .sink { [weak self] _ in
                guard let self, settings.hapticFeedback else { return }
                guard NSEvent.pressedMouseButtons == 0 else { return }
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            .store(in: &cancellables)

        // Les réglages changent l'apparence du notch : on relaie leurs notifications.
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        usage.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // L'étape de mise à jour change la hauteur du panneau ouvert : sans ce
        // relais, le bandeau s'afficherait dans une forme restée trop courte.
        Updater.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
