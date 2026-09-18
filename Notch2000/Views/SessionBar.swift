//
//  SessionBar.swift
//  Notch2000
//
//  La barre lumineuse collée au bord bas du notch : le seul élément toujours visible.
//

import SwiftUI

struct SessionBar: View {
    /// Part consommée de la session, de 0 à 1.
    var fill: Double
    /// Part écoulée de la fenêtre de 5 heures, pour le repère KITT.
    var elapsed: Double?
    var showKitt: Bool
    var isSyncing: Bool
    /// Départ et pointe du dégradé, choisis par le réglage de couleur.
    var colors: (base: Color, vivid: Color)
    /// Intensité du halo autour de la barre.
    var glow: GlowIntensity
    /// Rayon des coins de la forme, qui taille les extrémités de la barre.
    var cornerRadius: CGFloat

    @State private var scanPhase = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .bottomLeading) {
                if isSyncing {
                    scanner(width: width, height: height)
                } else {
                    filled(width: width, height: height)
                    if showKitt, let elapsed {
                        kitt(width: width, height: height, at: elapsed)
                    }
                }
            }
            .frame(width: width, height: height, alignment: .bottomLeading)
        }
        // Simple affectation : l'animer avec `withAnimation` embarquerait toute
        // la passe de rendu dans une animation « répéter indéfiniment », y
        // compris les vues voisines.
        .onAppear { scanPhase = isSyncing }
        .onChange(of: isSyncing) { scanPhase = isSyncing }
    }

    // MARK: - Éléments

    private func filled(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Theme.barHeight / 2, style: .continuous)
            // La progression s'échauffe vers sa pointe : l'œil suit le dégradé.
            .fill(
                LinearGradient(
                    colors: [colors.base, colors.vivid],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: max(width * fill, 0), height: Theme.barHeight)
            .modifier(InNotch(width: width, height: height, cornerRadius: cornerRadius))
            // Trois lueurs superposées : un cœur incandescent, un halo proche,
            // un débord diffus. Appliquées après la taille, elles rayonnent au
            // delà de la forme alors que le trait, lui, y reste enfermé.
            // Chacune est décalée vers le bas de son propre rayon : la lueur ne
            // remonte donc pas dans la découpe physique du notch, où il n'y a
            // aucun pixel pour l'afficher et où elle serait tranchée net.
            .shadow(color: colors.vivid.opacity(haloOpacity(0.95)), radius: halo(2), y: halo(2))
            .shadow(color: colors.vivid.opacity(haloOpacity(0.8)), radius: halo(5), y: halo(4))
            .shadow(color: colors.base.opacity(haloOpacity(0.55)), radius: halo(12), y: halo(10))
            .animation(Theme.fillAnimation, value: fill)
            .animation(Theme.fillAnimation, value: colors.vivid)
    }

    private func kitt(width: CGFloat, height: CGFloat, at position: Double) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Theme.kitt)
            .frame(width: Theme.kittWidth, height: Theme.barHeight)
            .offset(x: (width - Theme.kittWidth) * position)
            .modifier(InNotch(width: width, height: height, cornerRadius: cornerRadius))
            // Cœur blanc serré, puis deux halos : c'est le cœur qui détache le
            // repère du remplissage, pas l'étendue du halo.
            .shadow(
                color: .white.opacity(haloOpacity(1, boost: Theme.kittGlowOpacityBoost)),
                radius: halo(2, boost: Theme.kittGlowRadiusBoost),
                y: halo(1, boost: Theme.kittGlowRadiusBoost)
            )
            .shadow(
                color: .white.opacity(haloOpacity(0.9, boost: Theme.kittGlowOpacityBoost)),
                radius: halo(5, boost: Theme.kittGlowRadiusBoost),
                y: halo(3, boost: Theme.kittGlowRadiusBoost)
            )
            .shadow(
                color: Theme.kitt.opacity(haloOpacity(0.7, boost: Theme.kittGlowOpacityBoost)),
                radius: halo(10, boost: Theme.kittGlowRadiusBoost),
                y: halo(7, boost: Theme.kittGlowRadiusBoost)
            )
            .animation(Theme.fillAnimation, value: position)
    }

    /// Balayage pendant la lecture du quota : la barre est vide, un point la parcourt.
    private func scanner(width: CGFloat, height: CGFloat) -> some View {
        let travel = max(width - scannerWidth, 0)
        return RoundedRectangle(cornerRadius: Theme.barHeight / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Theme.scanner.opacity(0), Theme.scanner, Theme.scanner.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: scannerWidth, height: Theme.barHeight)
            .offset(x: scanPhase ? travel : 0)
            .modifier(InNotch(width: width, height: height, cornerRadius: cornerRadius))
            .shadow(color: Theme.scanner.opacity(haloOpacity(0.8)), radius: halo(8), y: halo(6))
            .animation(Theme.scanAnimation, value: scanPhase)
    }

    private var scannerWidth: CGFloat { 26 }

    /// Applique l'intensité choisie aux rayons comme aux décalages, pour que la
    /// lueur garde son orientation vers le bas quelle que soit sa force.
    private func halo(_ value: Double, boost: Double = 1) -> Double {
        value * glow.scale * boost
    }

    /// Même règle pour les opacités, bornées à 1 une fois le gain appliqué.
    private func haloOpacity(_ value: Double, boost: Double = 1) -> Double {
        min(halo(value, boost: boost), 1)
    }
}

/// Pose un élément au bas de la forme et le fait tailler par ses coins.
///
/// La taille intervient avant les lueurs, jamais après : c'est ce qui permet au
/// trait de partir du tout début du notch et de s'y faire manger, pendant que
/// son halo, appliqué ensuite, continue de déborder librement.
private struct InNotch: ViewModifier {
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: width, height: height, alignment: .bottomLeading)
            .clipShape(NotchShape(cornerRadius: cornerRadius, tuck: 0))
    }
}
