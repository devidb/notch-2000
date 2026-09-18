//
//  NotchWindowController.swift
//  Notch2000
//
//  Dérivé de NotchDrop (MIT, Lakr Aream) : fenêtre sans bordure ancrée en haut d'écran.
//

import Cocoa
import SwiftUI

/// Hauteur de la fenêtre hôte. Elle doit contenir le panneau ouvert dans son
/// état le plus grand, et surtout laisser de la place sous lui : la lueur de la
/// barre déborde d'une vingtaine de points, et le bord de la fenêtre la
/// trancherait net.
private let hostWindowHeight: CGFloat = Theme.panelSize.height + 72

@MainActor
final class NotchWindowController: NSWindowController {
    var vm: NotchViewModel?
    weak var screen: NSScreen?

    init(window: NSWindow, screen: NSScreen, usage: UsageModel) {
        self.screen = screen
        super.init(window: window)

        var notchSize = screen.notchSize
        // Sans notch physique, on retombe sur un gabarit proche d'un MacBook Pro 14 pouces.
        if notchSize == .zero {
            notchSize = CGSize(width: 185, height: max(screen.menuBarHeight, 24))
        }

        let vm = NotchViewModel(usage: usage)
        self.vm = vm
        vm.deviceNotchRect = CGRect(
            x: screen.frame.origin.x + (screen.frame.width - notchSize.width) / 2,
            y: screen.frame.origin.y + screen.frame.height - notchSize.height,
            width: notchSize.width,
            height: notchSize.height
        )
        vm.screenRect = screen.frame

        contentViewController = NotchViewController(vm)
        window.orderFrontRegardless()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    convenience init(screen: NSScreen, usage: UsageModel) {
        let window = NotchWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: window, screen: screen, usage: usage)

        window.setFrame(
            CGRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y + screen.frame.height - hostWindowHeight,
                width: screen.frame.width,
                height: hostWindowHeight
            ),
            display: false
        )
    }

    func destroy() {
        vm?.destroy()
        vm = nil
        window?.close()
        contentViewController = nil
        window = nil
    }
}
