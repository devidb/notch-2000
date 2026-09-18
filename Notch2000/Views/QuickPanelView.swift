//
//  QuickPanelView.swift
//  Notch2000
//
//  Seul écran de réglages de l'app : il s'ouvre dans le notch, au clic.
//
//  Toute la mise en page tient sur une grille unique : des rangées de hauteur
//  constante, trois tailles de texte et deux opacités. Les contrôles sont
//  alignés sur une même colonne à droite.
//

import AppKit
import SwiftUI

struct QuickPanelView: View {
    @ObservedObject var vm: NotchViewModel

    /// Hauteur commune à toutes les rangées de réglage.
    private let rowHeight: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            // Ce qui change l'information affichée.
            group {
                toggleRow(
                    "Repère de temps",
                    icon: "timer",
                    help: "Marque sur la barre la part des 5 heures déjà écoulée. S'il est dans l'orange, vous consommez plus vite que le temps ne passe.",
                    isOn: Binding(
                        get: { vm.settings.kittEnabled },
                        set: { vm.settings.kittEnabled = $0 }
                    )
                )
                toggleRow(
                    "Chiffres toujours visibles",
                    icon: "textformat.123",
                    help: "Affiche le pourcentage et le renouvellement en permanence, au lieu du seul survol.",
                    isOn: Binding(
                        get: { vm.settings.digitsAlwaysVisible },
                        set: { vm.settings.digitsAlwaysVisible = $0 }
                    )
                )
                row(
                    "Renouvellement",
                    icon: "clock.arrow.circlepath",
                    help: "Afficher l'heure du prochain renouvellement, ou le temps restant."
                ) {
                    segmented(
                        options: RenewalDisplay.allCases,
                        selection: vm.settings.renewalDisplay,
                        select: { vm.settings.renewalDisplay = $0 }
                    ) { option in
                        Image(systemName: option == .target ? "clock" : "hourglass")
                            .font(.system(size: 11))
                    }
                }
            }

            // Ce qui ne change que l'apparence.
            group {
                row(
                    "Couleur",
                    icon: "paintpalette",
                    help: "L'orange de Claude en permanence, ou une couleur qui suit la consommation : menthe, ambre puis braise."
                ) {
                    segmented(
                        options: BarPalette.allCases,
                        selection: vm.settings.barPalette,
                        select: { vm.settings.barPalette = $0 }
                    ) { option in
                        // Une pastille dit la couleur mieux que son nom.
                        Capsule()
                            .fill(swatch(for: option))
                            .frame(width: 22, height: 10)
                    }
                }
                row(
                    "Lueur",
                    icon: "sparkles",
                    help: "Intensité du halo autour de la barre : léger ou fort."
                ) {
                    segmented(
                        options: GlowIntensity.allCases,
                        selection: vm.settings.glowIntensity,
                        select: { vm.settings.glowIntensity = $0 }
                    ) { option in
                        Image(systemName: glowIcon(option))
                            .font(.system(size: 11))
                    }
                }
            }

            // Le reste : rien à voir avec ce qui est montré dans le notch.
            group {
                toggleRow(
                    "Ouvrir à la connexion",
                    icon: "rectangle.portrait.and.arrow.right",
                    help: "Lancer Notch2000 automatiquement à l'ouverture de votre session.",
                    isOn: Binding(
                        get: { vm.settings.launchAtLogin },
                        set: { vm.settings.launchAtLogin = $0 }
                    )
                )
                row(
                    "Actualiser",
                    icon: "arrow.clockwise",
                    help: "Fréquence de relecture du quota auprès d'Anthropic."
                ) {
                    // Une durée se lit en chiffres : aucune icône ne la dirait.
                    segmented(
                        options: RefreshRate.allCases,
                        selection: vm.settings.refreshRate,
                        select: { vm.settings.refreshRate = $0 }
                    ) { option in
                        Text(option == .everyMinute ? "1 min" : "5 min")
                            .font(Theme.panelCaption)
                    }
                }
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 20)
        .padding(.top, 42)
        .padding(.bottom, 14)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.usage.isSyncing ? "···" : "\(Int(vm.usage.percent.rounded())) %")
                    .font(Theme.panelDisplay)
                    .foregroundStyle(headlineColor)
                Text("de la session consommés")
                    .font(Theme.panelCaption)
                    .foregroundStyle(Theme.ivory(Theme.secondaryOpacity))
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(vm.usage.renewalLabel(vm.settings.renewalDisplay))
                    .font(Theme.panelDisplay)
                    .foregroundStyle(Theme.ivory)
                Text(vm.usage.renewalSubtitle(vm.settings.renewalDisplay))
                    .font(Theme.panelCaption)
                    .foregroundStyle(Theme.ivory(Theme.secondaryOpacity))
            }
        }
        .padding(.bottom, 16)
    }

    /// Du halo discret au halo franc.
    private func glowIcon(_ intensity: GlowIntensity) -> String {
        switch intensity {
        case .soft: "sun.min"
        case .strong: "sun.max"
        }
    }

    /// Aperçu de chaque palette : une pastille unie, ou le dégradé des trois paliers.
    private func swatch(for palette: BarPalette) -> LinearGradient {
        switch palette {
        case .claude:
            LinearGradient(
                colors: [Theme.clay, Theme.clayVivid],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .consumption:
            LinearGradient(
                colors: [Theme.mintVivid, Theme.amberVivid, Theme.emberVivid],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var headlineColor: Color {
        vm.usage.isAlert || vm.usage.isAtLimit
            ? Theme.barColors(vm.settings.barPalette, percent: vm.usage.percent).base
            : Theme.ivory
    }

    // MARK: - Pied

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                vm.usage.refreshNow()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accountConnected ? Theme.clay : Theme.ivory(0.3))
                        .frame(width: 5, height: 5)
                    Text(accountLabel)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(accountDetail)

            Spacer(minLength: 4)

            // Outil de mise au point, décommenter pour parcourir les trois paliers
            // de la palette de consommation : 35 %, 65 %, 92 %, puis le quota réel.
            // La mécanique reste en place dans `UsageModel.cyclePreview()`.
            //
            // Button {
            //     vm.usage.cyclePreview()
            // } label: {
            //     Image(systemName: vm.usage.previewPercent == nil ? "eye" : "eye.fill")
            //         .font(.system(size: 11))
            //         .foregroundStyle(
            //             vm.usage.previewPercent == nil
            //                 ? Theme.ivory(Theme.secondaryOpacity)
            //                 : Theme.barColors(vm.settings.barPalette, percent: vm.usage.percent).vivid
            //         )
            //         .contentShape(Rectangle())
            // }
            // .buttonStyle(.plain)
            // .help(Text("Aperçu des couleurs : 35 %, 65 %, 92 %, puis le quota réel"))

            if Updater.isAvailable {
                Button {
                    Updater.shared.checkForUpdates()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 11))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(Text("Rechercher une mise à jour"))
            }

            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Text("Quitter Notch2000"))
        }
        .font(Theme.panelCaption)
        .foregroundStyle(Theme.ivory(Theme.secondaryOpacity))
        .padding(.top, 12)
    }

    private var accountConnected: Bool {
        if case .unavailable = vm.usage.state { return false }
        return true
    }

    private var accountLabel: String {
        switch vm.usage.state {
        case .syncing: String(localized: "Lecture du quota…")
        case .live: String(localized: "Connecté")
        case .unavailable: String(localized: "Déconnecté")
        }
    }

    private var accountDetail: String {
        if case let .unavailable(reason) = vm.usage.state { return reason }
        return String(localized: "Quota lu depuis la session Claude Code")
    }

    // MARK: - Grille

    /// Bloc de rangées séparé du suivant par un filet unique.
    private func group(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) { content() }
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.ivory(0.1)).frame(height: 1)
            }
    }

    private func row(
        _ title: LocalizedStringKey,
        icon: String,
        help: LocalizedStringKey,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.ivory(Theme.secondaryOpacity))
                // Colonne d'icônes de largeur constante : les libellés s'alignent.
                .frame(width: 16)
            Text(title)
                .font(Theme.panelBody)
                .foregroundStyle(Theme.ivory)
            Spacer(minLength: 4)
            trailing()
        }
        .frame(height: rowHeight)
        .help(Text(help))
    }

    private func toggleRow(
        _ title: LocalizedStringKey,
        icon: String,
        help: LocalizedStringKey,
        isOn: Binding<Bool>
    ) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            row(title, icon: icon, help: help) { MiniToggle(isOn: isOn.wrappedValue) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func segmented<Option: Hashable, Content: View>(
        options: [Option],
        selection: Option,
        select: @escaping (Option) -> Void,
        @ViewBuilder content: @escaping (Option) -> Content
    ) -> some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    select(option)
                } label: {
                    content(option)
                        .foregroundStyle(selected ? Theme.ivory : Theme.ivory(Theme.secondaryOpacity))
                        .frame(minWidth: 30)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(
                            selected ? Theme.ivory(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.ivory(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// Interrupteur compact : celui d'AppKit est trop grand pour le panneau.
struct MiniToggle: View {
    var isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Theme.clay : Theme.ivory(0.18))
            .frame(width: 26, height: 15)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Theme.ivory)
                    .frame(width: 11, height: 11)
                    .padding(.horizontal, 2)
            }
            .animation(.easeInOut(duration: 0.16), value: isOn)
    }
}
