//
//  DebugWindow.swift
//  Notch2000
//
//  Fenêtre de développement : deux curseurs forcent le pourcentage de session
//  et le temps restant sans toucher à l'API, et une ligne relève la marge HDR
//  de l'écran. Ses textes ne sont pas localisés.
//
//  Désactivée pour la publication, mais conservée : pour la rétablir, retirer
//  le commentaire qui entoure le code ci-dessous et celui de l'appel
//  `DebugWindow.showIfEnabled` dans `AppDelegate`, puis lancer l'app avec
//  `N2K_DEBUG=1`.
//

/*
import AppKit
import SwiftUI

@MainActor
enum DebugWindow {
    private static var panel: NSPanel?

    static var isEnabled: Bool { ProcessInfo.processInfo.environment["N2K_DEBUG"] == "1" }

    static func showIfEnabled(usage: UsageModel) {
        guard isEnabled, panel == nil else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 170),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Notch2000 · debug"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: DebugView(usage: usage))
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel
    }
}

/// Relevé, une fois par seconde, de la marge HDR et de l'état de l'app. Lecture
/// seule : rien de ce qui est mesuré ici ne modifie le rendu du notch.
@MainActor
private final class HDRProbe: ObservableObject {
    @Published private(set) var headroom: CGFloat = 1
    @Published private(set) var isActive = false
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.read() }
        }
        read()
    }

    private func read() {
        let screen = NSScreen.buildin ?? NSScreen.main
        headroom = screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1
        isActive = NSApp.isActive
    }
}

private struct DebugView: View {
    @ObservedObject var usage: UsageModel
    @StateObject private var probe = HDRProbe()
    @State private var forced = true
    @State private var percent: Double = 29
    @State private var timeForced = true
    @State private var remaining: Double = 126

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $forced) { Text(verbatim: "Forcer le % de session") }
            HStack {
                Slider(value: $percent, in: 0...100, step: 1)
                Text(verbatim: "\(Int(percent)) %")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            .disabled(!forced)

            Toggle(isOn: $timeForced) { Text(verbatim: "Forcer le temps restant") }
            HStack {
                Slider(value: $remaining, in: 0...300, step: 1)
                Text(verbatim: "\(Int(remaining) / 60)h\(String(format: "%02d", Int(remaining) % 60))")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            .disabled(!timeForced)





            Text(verbatim: String(
                format: "Marge HDR : ×%.2f (%.1f diaph.) · app %@",
                probe.headroom, log2(max(probe.headroom, 1)), probe.isActive ? "active" : "inactive"
            ))
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)

        }
        .padding(14)
        .frame(width: 420)
        .onAppear(perform: apply)
        .onChange(of: percent) { apply() }
        .onChange(of: forced) { apply() }
        .onChange(of: remaining) { apply() }
        .onChange(of: timeForced) { apply() }
    }

    private func apply() {
        usage.setPreviewPercent(forced ? percent : nil)
        usage.setPreviewRemainingMinutes(timeForced ? remaining : nil)
    }
}
*/
