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
                    // Au survol la forme est descendue : toute sa surface ouvre,
                    // bande des chiffres comprise.
                    let target = status == .hovered ? hoveredShapeRect : hoverRect
                    if target.contains(location) { open() }
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

        // Les réglages changent l'apparence du notch : on relaie leurs notifications.
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        usage.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
