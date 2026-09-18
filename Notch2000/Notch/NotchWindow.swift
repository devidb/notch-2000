//
//  NotchWindow.swift
//  Notch2000
//
//  Dérivé de NotchDrop (MIT, Lakr Aream).
//

import Cocoa

class NotchWindow: NSWindow {
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )

        isOpaque = false
        alphaValue = 1
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = NSColor.clear
        isMovable = false
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        // La lueur descend d'une vingtaine de points sous la barre de menus,
        // donc en plein territoire des fenêtres ordinaires. Au niveau
        // `statusBar`, il suffit d'une fenêtre flottante ou d'un panneau modal
        // pour la recouvrir : on se place au dessus de toutes ces familles.
        // Seuls les menus déroulants du système partagent ce niveau, et ils
        // passent devant à l'ouverture, ce qui est le comportement attendu.
        level = .popUpMenu
        hasShadow = false
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
