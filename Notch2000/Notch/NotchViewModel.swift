//
//  NotchViewModel.swift
//  Notch2000
//
//  Dérivé de NotchDrop (MIT, Lakr Aream) : la machine à états et la géométrie
//  d'écran viennent de là, les tailles et les réglages sont ceux de Notch2000.
//

import Cocoa
import Combine
import Foundation
import SwiftUI

@MainActor
final class NotchViewModel: NSObject, ObservableObject {
    var cancellables: Set<AnyCancellable> = []

    /// Marge ajoutée autour de la forme pour rattraper le pointeur un peu avant le bord.
    let hoverInset: CGFloat = -4
    /// Marge supplémentaire pour quitter le survol. La forme survolée a la même
    /// largeur qu'au repos : sans cet écart, un pointeur qui longe le bord entre
    /// et sort sans arrêt, et chaque entrée relance le retour haptique.
    let unhoverInset: CGFloat = -10

    let settings = Settings.shared
    let usage: UsageModel

    enum Status: String, Codable, Hashable {
        /// La barre seule, aux dimensions du notch.
        case closed
        /// La forme descend sous la caméra et les chiffres apparaissent.
        case hovered
        /// Le panneau de réglages rapides est ouvert.
        case opened
    }

    @Published private(set) var status: Status = .closed
    @Published var deviceNotchRect: CGRect = .zero
    @Published var screenRect: CGRect = .zero

    init(usage: UsageModel) {
        self.usage = usage
        super.init()
        setupCancellables()
    }

    // MARK: - Géométrie

    /// Débord sous la découpe, selon le dessin de la jauge.
    var overhang: CGFloat { Theme.overhang(settings.barStyle) }

    /// Taille de la forme noire dessinée sous le notch, selon l'état courant.
    var shapeSize: CGSize {
        let width = deviceNotchRect.width
        let height = deviceNotchRect.height + overhang

        switch status {
        case .closed:
            // Les chiffres permanents ont besoin de leur bande, même sans survol.
            let band = settings.digitsAlwaysVisible ? Theme.digitsBand : 0
            return CGSize(width: width, height: height + band)
        case .hovered:
            return CGSize(width: width, height: height + Theme.digitsBand + Theme.hoverLift)
        case .opened:
            return openedSize
        }
    }

    /// Taille du panneau ouvert.
    var openedSize: CGSize { Theme.panelSize }

    var cornerRadius: CGFloat {
        status == .opened ? Theme.cornerRadiusPanel : Theme.cornerRadiusClosed
    }

    /// Zone écran occupée par la forme au repos, débord compris, et bande des
    /// chiffres quand ils restent affichés.
    private var closedShapeRect: CGRect {
        let band = settings.digitsAlwaysVisible ? Theme.digitsBand : 0
        return CGRect(
            x: deviceNotchRect.minX,
            y: deviceNotchRect.minY - overhang - band,
            width: deviceNotchRect.width,
            height: deviceNotchRect.height + overhang + band
        )
    }

    /// Zone qui déclenche le survol et accepte le clic d'ouverture.
    var hoverRect: CGRect {
        closedShapeRect.insetBy(dx: hoverInset, dy: hoverInset)
    }

    /// Zone occupée une fois la bande des chiffres descendue : elle accepte le
    /// clic d'ouverture.
    var hoveredShapeRect: CGRect {
        let width = deviceNotchRect.width
        let height = deviceNotchRect.height + overhang + Theme.digitsBand + Theme.hoverLift
        return CGRect(
            x: deviceNotchRect.midX - width / 2,
            y: deviceNotchRect.maxY - height,
            width: width,
            height: height
        ).insetBy(dx: hoverInset, dy: hoverInset)
    }

    /// Zone à prendre en compte pour le suivi du pointeur dans l'état courant.
    var activeHoverRect: CGRect {
        switch status {
        case .closed: hoverRect
        // Un peu plus large que la forme : on ne quitte le survol qu'en s'en éloignant.
        case .hovered: hoveredShapeRect.insetBy(dx: unhoverInset, dy: unhoverInset)
        case .opened: openedRect
        }
    }

    /// Zone du panneau ouvert, utilisée pour distinguer un clic intérieur d'un clic extérieur.
    var openedRect: CGRect {
        let size = openedSize
        return CGRect(
            x: screenRect.midX - size.width / 2,
            y: screenRect.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Bandeau supérieur du panneau : y cliquer referme, comme sur le notch au repos.
    var openedHeadlineRect: CGRect {
        CGRect(
            x: screenRect.midX - Theme.panelSize.width / 2,
            y: screenRect.maxY - deviceNotchRect.height,
            width: Theme.panelSize.width,
            height: deviceNotchRect.height
        )
    }

    // MARK: - Transitions

    func open() {
        guard status != .opened else { return }
        withAnimation(Theme.shapeAnimation) { status = .opened }
        NSApp.activate(ignoringOtherApps: true)
        usage.refreshNow()
        // L'ouverture à la connexion a pu changer dans les Réglages Système.
        settings.refreshLaunchAtLogin()
    }

    func close() {
        guard status != .closed else { return }
        withAnimation(Theme.shapeAnimation) { status = .closed }
    }

    func hover() {
        guard status == .closed else { return }
        withAnimation(Theme.shapeAnimation) { status = .hovered }
    }

    func unhover() {
        guard status == .hovered else { return }
        withAnimation(Theme.shapeAnimation) { status = .closed }
    }

    func destroy() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
