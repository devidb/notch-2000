//
//  NotchRootView.swift
//  Notch2000
//
//  Assemble la forme, la barre de session, les chiffres et le panneau.
//

import SwiftUI

struct NotchRootView: View {
    @StateObject var vm: NotchViewModel

    /// Le raccord ne sert qu'à fondre un élargissement dans la barre de menus.
    /// Au repos, la forme épouse le notch : tout raccord déborderait sur les côtés.
    private var tuck: CGFloat {
        vm.shapeSize.width > vm.deviceNotchRect.width + 1 ? Theme.tuck : 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            shape
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // La fenêtre hôte couvre toute la largeur de l'écran : hors panneau ouvert,
        // elle doit laisser passer les clics vers la barre de menus et les apps.
        // L'ouverture et la fermeture passent par les moniteurs globaux.
        .allowsHitTesting(vm.status == .opened)
        .preferredColorScheme(.dark)
        // Autorise les couleurs HDR de la jauge sur les écrans qui les affichent.
        .allowedDynamicRange(.high)
    }

    // MARK: - Forme

    private var shape: some View {
        let size = vm.shapeSize

        return ZStack(alignment: .top) {
            // Seule la forme noire suit le ressort. Son rebond ne doit jamais
            // servir de cadre de mise en page au texte, sinon celui-ci est
            // comprimé puis projeté hors du notch pendant la transition.
            NotchShape(cornerRadius: vm.cornerRadius, tuck: tuck)
                .fill(.black)
                .frame(width: size.width + tuck * 2, height: size.height)
                // Suivre la taille et non l'état : le panneau se déplie aussi
                // quand la mise à jour s'invite, sans changer d'état.
                .animation(Theme.shapeAnimation, value: size)

            content(size: size)
        }
        // Conteneur immobile, dimensionné pour le plus grand état : les enfants
        // changent de taille, le cadre lui ne bouge pas.
        .frame(
            width: Theme.panelSize.width + tuck * 2,
            height: Theme.panelSize.height,
            alignment: .top
        )
    }

    private func content(size: CGSize) -> some View {
        ZStack(alignment: .top) {
            // Taille finale dès la première image : le panneau ne se met jamais
            // en page dans une forme encore en train de s'ouvrir.
            if vm.status == .opened {
                QuickPanelView(vm: vm)
                    .frame(width: vm.openedSize.width, height: vm.openedSize.height)
                    .transition(.opacity)
                    .animation(Theme.digitsFade, value: vm.status)
            }

        }
        // Seul le panneau est révélé par la forme : ce qui dépasse est coupé.
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(NotchShape(cornerRadius: vm.cornerRadius, tuck: 0))
        .animation(Theme.shapeAnimation, value: size)
        // La barre est posée par dessus : elle se taille elle-même sur les coins
        // du notch, puis applique sa lueur, qui déborde donc librement.
        .overlay(alignment: .bottom) {
            gauge
                .frame(width: size.width, height: size.height)
                .animation(Theme.shapeAnimation, value: size)
        }
        // Les chiffres sont posés par dessus, hors du sous-arbre que le ressort
        // anime : ils ne suivent donc jamais les rebonds de la forme.
        .overlay(alignment: .top) {
            digits
                .opacity(digitsOpacity)
                .animation(Theme.digitsFade, value: digitsOpacity)
        }
    }

    /// La jauge, trait ou carrés. Pendant la lecture du quota, le balayage de la
    /// barre sert dans les deux cas : il n'y a pas encore de valeur à découper.
    @ViewBuilder
    private var gauge: some View {
        if vm.settings.barStyle == .dots, !vm.usage.isSyncing {
            SessionDots(
                fill: vm.usage.fillFraction,
                elapsed: vm.usage.elapsedFraction,
                showKitt: showsKitt,
                colors: barColors,
                glow: vm.settings.glowIntensity,
                cornerRadius: vm.cornerRadius,
                hdrStops: hdrStops
            )
        } else {
            SessionBar(
                fill: vm.usage.fillFraction,
                elapsed: vm.usage.elapsedFraction,
                showKitt: showsKitt,
                isSyncing: vm.usage.isSyncing,
                colors: barColors,
                glow: vm.settings.glowIntensity,
                cornerRadius: vm.cornerRadius,
                hdrStops: hdrStops
            )
        }
    }

    /// Chiffres poussés en HDR avec la jauge, un cran en dessous.
    private var digitsStops: Double {
        vm.settings.hdrEnabled ? Theme.digitsHDRStops : 0
    }

    private var hdrStops: Double {
        vm.settings.hdrEnabled ? Theme.hdrStops : 0
    }

    /// Les chiffres logent dans une bande sous la caméra, juste au dessus de la
    /// jauge, chacun à côté de ce qu'il mesure : le pourcentage au bout du
    /// remplissage, l'heure au repère du temps écoulé.
    ///
    /// Le cadre suit la taille finale et non celle que le ressort anime : les
    /// chiffres ne rebondissent pas avec la forme.
    private var digits: some View {
        let layout = RidingDigits(fill: vm.usage.fillFraction, elapsed: vm.usage.elapsedFraction ?? 1)
        return layout {
            Text(vm.usage.percentLabel)
                .foregroundStyle(barColors.base.hdr(digitsStops))
            Text(vm.usage.renewalLabel(vm.settings.renewalDisplay))
                .foregroundStyle(Theme.kitt.hdr(digitsStops))
        }
        .font(Theme.inlineDigits)
        .lineLimit(1)
        .frame(width: vm.deviceNotchRect.width, height: Theme.digitsBand)
        // Au survol, la forme descend de quelques points : les chiffres la
        // suivent, au rythme de la jauge, pour rester posés dessus.
        .padding(.top, vm.deviceNotchRect.height + (vm.status == .hovered ? Theme.hoverLift : 0))
        .animation(Theme.shapeAnimation, value: vm.status)
        .animation(Theme.fillAnimation, value: vm.usage.fillFraction)
        .animation(Theme.fillAnimation, value: vm.usage.elapsedFraction)
    }

    private var barColors: (base: Color, vivid: Color) {
        Theme.barColors(vm.settings.barPalette, percent: vm.usage.percent)
    }

    /// Pleinement lisibles dès qu'ils sont affichés, au survol comme en permanence.
    private var digitsOpacity: Double {
        switch vm.status {
        case .opened: 0
        case .hovered: 1
        case .closed: vm.settings.digitsAlwaysVisible ? 1 : 0
        }
    }

    // MARK: - Règles d'affichage

    private var showsDigits: Bool {
        guard vm.status != .opened else { return false }
        return vm.status == .hovered || vm.settings.digitsAlwaysVisible
    }

    /// Le repère reste visible au survol : l'heure s'y accroche.
    private var showsKitt: Bool {
        vm.settings.kittEnabled && vm.status != .opened
    }
}

/// Pose l'heure au dessus du repère KITT et le pourcentage au bout du remplissage.
///
/// L'heure a la priorité : elle reste centrée sur le repère, seuls les bords de
/// la forme la retiennent. Quand le pourcentage la rejoindrait, c'est lui qui
/// s'écarte et se range contre elle, du côté où se trouve la pointe.
private struct RidingDigits: Layout {
    var fill: Double
    var elapsed: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let percent = subviews[0].sizeThatFits(.unspecified).width
        let time = subviews[1].sizeThatFits(.unspecified).width
        let gap = Theme.digitsGap
        let lower = Theme.digitsInset
        let upper = bounds.width - Theme.digitsInset

        let tip = bounds.width * fill
        let kittCenter = (bounds.width - Theme.kittWidth) * elapsed + Theme.kittWidth / 2

        let timeX = clamp(kittCenter - time / 2, lower, upper - time)
        var percentX = clamp(tip - gap - percent, lower, upper - percent)

        let overlaps = percentX < timeX + time + gap && percentX + percent + gap > timeX
        if overlaps {
            let before = timeX - gap - percent
            let after = timeX + time + gap
            let tipIsBefore = tip < kittCenter
            // Du côté de la pointe si la place le permet, sinon de l'autre.
            if tipIsBefore {
                percentX = before >= lower ? before : after
            } else {
                percentX = after + percent <= upper ? after : before
            }
        }

        let y = bounds.midY
        subviews[0].place(at: CGPoint(x: bounds.minX + percentX, y: y), anchor: .leading, proposal: .unspecified)
        subviews[1].place(at: CGPoint(x: bounds.minX + timeX, y: y), anchor: .leading, proposal: .unspecified)
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}
