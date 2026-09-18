//
//  HighDynamicRange.swift
//  Notch2000
//
//  Garde la marge HDR de la jauge quand l'app passe en arrière-plan.
//
//  SwiftUI laisse ses calques en plage dynamique automatique : c'est alors le
//  système qui dose le HDR, et il le retire à une app qui n'est plus au premier
//  plan. Notch2000 n'y est presque jamais. Sans marge, macOS écrête chaque
//  composante : le saumon vire au blanc, le blanc au gris, jusqu'au prochain
//  redessin.
//
//  On demande donc explicitement la plage haute sur les calques de la fenêtre
//  du notch, et seulement quand l'éclat HDR est actif : elle coûte de la
//  batterie. `preferredDynamicRange` ne vaut que pour le calque qui le porte,
//  pas pour ses descendants, et SwiftUI recrée ses calques à sa guise : l'arbre
//  est parcouru en entier, et de nouveau à intervalle régulier.
//

import AppKit

enum HighDynamicRange {
    /// Intervalle entre deux passages sur l'arbre des calques.
    static let refreshInterval: TimeInterval = 2

    @MainActor
    static func apply(to window: NSWindow, enabled: Bool) {
        guard #available(macOS 26, *), let root = window.contentView?.layer else { return }
        // Éteint, on rend aux calques leur valeur par défaut au lieu de choisir
        // pour eux : une plage modifiée fait varier la marge HDR de l'écran.
        let range: CALayer.DynamicRange = enabled ? .high : .standard
        var stack = [root]
        while let layer = stack.popLast() {
            if layer.preferredDynamicRange != range { layer.preferredDynamicRange = range }
            stack.append(contentsOf: layer.sublayers ?? [])
        }
    }
}
