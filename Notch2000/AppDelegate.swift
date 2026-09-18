//
//  AppDelegate.swift
//  Notch2000
//
//  Dérivé de NotchDrop (MIT, Lakr Aream) : reconstruction des fenêtres au changement d'écran.
//

import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: NotchWindowController?
    private var usage: UsageModel!
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)

        usage = UsageModel(refreshInterval: TimeInterval(Settings.shared.refreshRate.rawValue))
        usage.start()

        // Le réglage de fréquence prend effet sans redémarrage.
        Settings.shared.$refreshRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.usage.refreshInterval = TimeInterval(rate.rawValue)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildApplicationWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        _ = EventMonitors.shared
        // Instancie Sparkle, qui planifie alors ses vérifications.
        _ = Updater.shared
        rebuildApplicationWindows()
    }

    func applicationWillTerminate(_: Notification) {
        try? FileManager.default.removeItem(at: pidFile)
    }

    /// Le notch de l'écran intégré prime ; sinon on retombe sur l'écran principal.
    private func findScreenFitsOurNeeds() -> NSScreen? {
        if let screen = NSScreen.buildin, screen.notchSize != .zero { return screen }
        return NSScreen.buildin ?? .main
    }

    @objc func rebuildApplicationWindows() {
        mainWindowController?.destroy()
        mainWindowController = nil
        guard let screen = findScreenFitsOurNeeds() else { return }
        mainWindowController = NotchWindowController(screen: screen, usage: usage)
    }

    /// Relancer l'app depuis le Finder ouvre le panneau plutôt qu'une fenêtre.
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        mainWindowController?.vm?.open()
        return true
    }
}
