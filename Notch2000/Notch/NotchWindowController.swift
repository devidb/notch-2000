//
//  NotchWindowController.swift
//  Notch2000
//
//  Dérivé de NotchDrop (MIT, Lakr Aream) : fenêtre sans bordure ancrée en haut d'écran.
//

import Cocoa
import Combine
import SwiftUI

/// Hauteur de la fenêtre hôte. Elle doit contenir le panneau ouvert, et
/// surtout laisser de la place sous lui : la lueur de la
/// barre déborde d'une vingtaine de points, et le bord de la fenêtre la
/// trancherait net.
private let hostWindowHeight: CGFloat = Theme.panelSize.height + 72

@MainActor
final class NotchWindowController: NSWindowController {
    var vm: NotchViewModel?
    weak var screen: NSScreen?

    private var cancellables: Set<AnyCancellable> = []

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

        // Panneau ouvert, la fenêtre prend le clavier : sans cela elle n'est
        // jamais principale, et le suivi du pointeur qui alimente la ligne
        // d'aide ne reçoit rien de fiable.
        vm.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak window] status in
                guard let window, status == .opened else { return }
                window.makeKeyAndOrderFront(nil)
            }
            .store(in: &cancellables)

        // Plage HDR haute tant que l'éclat HDR est actif, voir `HighDynamicRange`.
        Settings.shared.$hdrEnabled
            .combineLatest(
                Timer.publish(every: HighDynamicRange.refreshInterval, on: .main, in: .common)
                    .autoconnect()
                    .prepend(Date())
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak window] enabled, _ in
                guard let window else { return }
                HighDynamicRange.apply(to: window, enabled: enabled)
            }
            .store(in: &cancellables)

        // Une app qui passe au premier plan peut réordonner les fenêtres de son
        // niveau ; on se remet devant sans jamais voler le focus.
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak window] _ in window?.orderFrontRegardless() }
            .store(in: &cancellables)
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
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        vm?.destroy()
        vm = nil
        window?.close()
        contentViewController = nil
        window = nil
    }
}
