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
            width: Theme.panelMaxSize.width + tuck * 2,
            height: Theme.panelMaxSize.height,
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
                cornerRadius: vm.cornerRadius
            )
        } else {
            SessionBar(
                fill: vm.usage.fillFraction,
                elapsed: vm.usage.elapsedFraction,
                showKitt: showsKitt,
                isSyncing: vm.usage.isSyncing,
                colors: barColors,
                glow: vm.settings.glowIntensity,
                cornerRadius: vm.cornerRadius
            )
        }
    }

    /// Les chiffres logent dans les oreilles déployées, jamais sous la découpe.
    ///
    /// Chaque valeur est ancrée à un coin d'un cadre de taille fixe : quand le
    /// texte change (une minute qui passe), seul son bord intérieur bouge et
    /// aucun recalcul de pile ne vient le déplacer.
    private var digits: some View {
        Color.clear
            .frame(width: expandedWidth, height: notchBandHeight)
            .overlay(alignment: .bottomLeading) {
                Text(vm.usage.percentLabel)
                    .padding(.leading, 7)
                    .padding(.bottom, digitsLift)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(vm.usage.renewalLabel(vm.settings.renewalDisplay))
                    .padding(.trailing, 7)
                    .padding(.bottom, digitsLift)
            }
            .font(Theme.inlineDigits)
            .foregroundStyle(digitsColor)
            .lineLimit(1)
            .fixedSize()
    }

    /// Hauteur des chiffres au dessus du bord : en mode carrés, ils se posent
    /// au dessus de la rangée plutôt que dessus.
    private var digitsLift: CGFloat {
        vm.settings.barStyle == .dots ? Theme.dotInset + Theme.dotSize + 3 : 4
    }

    private var barColors: (base: Color, vivid: Color) {
        Theme.barColors(vm.settings.barPalette, percent: vm.usage.percent)
    }

    /// Aux niveaux hauts, les chiffres empruntent la couleur de la barre.
    private var digitsColor: Color {
        vm.usage.isAlert || vm.usage.isAtLimit ? barColors.base : Theme.ivory(0.85)
    }

    /// Trois niveaux : absent, discret en permanence, pleinement lisible au survol.
    /// Sans cela, activer les chiffres permanents rendrait le survol invisible.
    private var digitsOpacity: Double {
        switch vm.status {
        case .opened: 0
        case .hovered: 1
        case .closed: vm.settings.digitsAlwaysVisible ? 0.45 : 0
        }
    }

    // MARK: - Mesures

    /// Largeur de la forme une fois les oreilles sorties.
    private var expandedWidth: CGFloat {
        vm.deviceNotchRect.width + Theme.hoverWidening
    }

    /// Hauteur de la bande qui borde la découpe, débord compris.
    private var notchBandHeight: CGFloat {
        vm.deviceNotchRect.height + vm.overhang
    }

    // MARK: - Règles d'affichage

    private var showsDigits: Bool {
        guard vm.status != .opened else { return false }
        return vm.status == .hovered || vm.settings.digitsAlwaysVisible
    }

    /// Le repère disparaît pendant le survol, pour laisser la barre lisible.
    private var showsKitt: Bool {
        guard vm.settings.kittEnabled, vm.status != .opened else { return false }
        return vm.settings.digitsAlwaysVisible || vm.status != .hovered
    }
}
