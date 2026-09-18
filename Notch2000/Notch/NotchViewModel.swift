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

    let settings = Settings.shared
    let usage: UsageModel

    enum Status: String, Codable, Hashable {
        /// La barre seule, aux dimensions du notch.
        case closed
        /// Les oreilles sont déployées et les chiffres apparaissent.
        case hovered
        /// Le panneau de réglages rapides est ouvert.
        case opened
    }

    @Published private(set) var status: Status = .closed
    @Published var deviceNotchRect: CGRect = .zero
    @Published var screenRect: CGRect = .zero

    let hapticSender = PassthroughSubject<Void, Never>()

    init(usage: UsageModel) {
        self.usage = usage
        super.init()
        setupCancellables()
    }

    // MARK: - Géométrie

    /// Taille de la forme noire dessinée sous le notch, selon l'état courant.
    var shapeSize: CGSize {
        let width = deviceNotchRect.width
        let height = deviceNotchRect.height + Theme.shapeOverhang

        switch status {
        case .closed:
            // Les chiffres permanents ont besoin des oreilles, même sans survol.
            let widened = settings.digitsAlwaysVisible ? Theme.hoverWidening : 0
            return CGSize(width: width + widened, height: height)
        case .hovered:
            return CGSize(width: width + Theme.hoverWidening, height: height)
        case .opened:
            return Theme.panelSize
        }
    }

    var cornerRadius: CGFloat {
        status == .opened ? Theme.cornerRadiusPanel : Theme.cornerRadiusClosed
    }

    /// Zone écran occupée par la forme au repos, débord compris.
    private var closedShapeRect: CGRect {
        CGRect(
            x: deviceNotchRect.minX,
            y: deviceNotchRect.minY - Theme.shapeOverhang,
            width: deviceNotchRect.width,
            height: deviceNotchRect.height + Theme.shapeOverhang
        )
    }

    /// Zone qui déclenche le survol et accepte le clic d'ouverture.
    var hoverRect: CGRect {
        closedShapeRect.insetBy(dx: hoverInset, dy: hoverInset)
    }

    /// Zone occupée une fois les oreilles déployées : le pointeur peut s'y promener
    /// sans refermer la forme.
    private var hoveredShapeRect: CGRect {
        let width = deviceNotchRect.width + Theme.hoverWidening
        let height = deviceNotchRect.height + Theme.shapeOverhang
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
        case .hovered: hoveredShapeRect
        case .opened: openedRect
        }
    }

    /// Zone du panneau ouvert, utilisée pour distinguer un clic intérieur d'un clic extérieur.
    var openedRect: CGRect {
        CGRect(
            x: screenRect.midX - Theme.panelSize.width / 2,
            y: screenRect.maxY - Theme.panelSize.height,
            width: Theme.panelSize.width,
            height: Theme.panelSize.height
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
    }

    func close() {
        guard status != .closed else { return }
        withAnimation(Theme.shapeAnimation) { status = .closed }
    }

    func hover() {
        guard status == .closed else { return }
        withAnimation(Theme.shapeAnimation) { status = .hovered }
        hapticSender.send()
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
