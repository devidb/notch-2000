//
//  SessionDots.swift
//  Notch2000
//
//  La jauge en carrés : même information, mêmes couleurs et même lueur que
//  `SessionBar`, découpée en une rangée de carrés. La lueur en reprend les
//  valeurs à l'identique, orientées vers le bas : elle ne doit jamais s'écarter
//  de celle de la barre.
//

import SwiftUI

struct SessionDots: View {
    /// Part consommée de la session, de 0 à 1.
    var fill: Double
    /// Part écoulée de la fenêtre de 5 heures, pour le repère KITT.
    var elapsed: Double?
    var showKitt: Bool
    var colors: (base: Color, vivid: Color)
    var glow: GlowIntensity
    var cornerRadius: CGFloat
    /// Surexposition HDR des carrés allumés et du repère, en diaphragmes.
    var hdrStops: Double

    var body: some View {
        GeometryReader { proxy in
            let layout = Layout(width: proxy.size.width, cornerRadius: cornerRadius)
            let lit = layout.count(for: fill)

            ZStack(alignment: .bottomLeading) {
                off(layout)
                    .modifier(Settled(width: proxy.size.width))
                    .modifier(DotsInNotch(size: proxy.size, cornerRadius: cornerRadius))

                litRow(layout, lit: lit)
                    .animation(Theme.fillAnimation, value: fill)
                    .animation(Theme.fillAnimation, value: colors.vivid)
                    .modifier(Settled(width: proxy.size.width))
                    .modifier(DotsInNotch(size: proxy.size, cornerRadius: cornerRadius))
                    .shadow(color: colors.vivid.opacity(haloOpacity(0.95)), radius: halo(2), y: halo(2))
                    .shadow(color: colors.vivid.opacity(haloOpacity(0.8)), radius: halo(5), y: halo(4))
                    .shadow(color: colors.base.opacity(haloOpacity(0.55)), radius: halo(12), y: halo(10))

                if showKitt, let elapsed {
                    kitt(layout, index: layout.index(for: elapsed))
                        .animation(Theme.fillAnimation, value: elapsed)
                        .modifier(Settled(width: proxy.size.width))
                        .modifier(DotsInNotch(size: proxy.size, cornerRadius: cornerRadius))
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
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
        }
    }

    // MARK: - Rangées

    /// Les carrés éteints : ils dessinent la graduation sans rien éclairer.
    private func off(_ layout: Layout) -> some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(0..<layout.count, id: \.self) { index in
                Rectangle()
                    .fill(Theme.dotOff)
                    .frame(width: Theme.dotSize, height: Theme.dotSize)
                    .offset(x: layout.x(index))
            }
        }
    }

    /// Les carrés allumés : un seul dégradé, du départ à la pointe, découpé par
    /// les carrés. La progression s'échauffe vers sa pointe, comme la barre.
    private func litRow(_ layout: Layout, lit: Int) -> some View {
        LinearGradient(colors: [colors.base.hdr(hdrStops), colors.vivid.hdr(hdrStops)], startPoint: .leading, endPoint: .trailing)
            .frame(width: layout.span(lit), height: Theme.dotSize)
            .mask(alignment: .leading) {
                ZStack(alignment: .leading) {
                    ForEach(0..<lit, id: \.self) { index in
                        Rectangle()
                            .frame(width: Theme.dotSize, height: Theme.dotSize)
                            .offset(x: layout.x(index) - layout.inset)
                    }
                }
                .frame(width: layout.span(lit), height: Theme.dotSize, alignment: .leading)
            }
            .offset(x: layout.inset)
    }

    private func kitt(_ layout: Layout, index: Int) -> some View {
        Rectangle()
            .fill(Theme.kitt.hdr(hdrStops))
            // Un cran plus haut que les carrés, comme sur la barre.
            .frame(width: Theme.dotSize, height: Theme.dotSize + Theme.kittRise)
            .offset(x: layout.x(index))
    }

    // MARK: - Lueur, reprise de SessionBar

    ///
    /// Le surcroît du repère ne vaut qu'en lueur intense : il sert à le détacher
    /// d'un halo de barre puissant. En lueur douce, le repère baisse comme elle.
    private func halo(_ value: Double, boost: Double = 1) -> Double {
        value * glow.scale * (glow == .strong ? boost : 1)
    }

    private func haloOpacity(_ value: Double, boost: Double = 1) -> Double {
        min(halo(value, boost: boost), 1)
    }

    // MARK: - Disposition

    /// Rangée à pas fixe, centrée dans la forme : tous les écarts sont égaux,
    /// et le reste de largeur se partage entre les deux marges, loin des coins
    /// arrondis qui rogneraient les carrés.
    private struct Layout {
        var width: CGFloat
        var cornerRadius: CGFloat

        private var pitch: CGFloat { Theme.dotSize + Theme.dotGap }
        private var minInset: CGFloat { (cornerRadius * 0.55).rounded() }

        var count: Int {
            let usable = width - minInset * 2 + Theme.dotGap
            return max(Int(usable / pitch), 2)
        }

        /// Marge gauche, arrondie au point pour garder des carrés nets.
        var inset: CGFloat {
            let row = CGFloat(count) * pitch - Theme.dotGap
            return ((width - row) / 2).rounded(.down)
        }

        func x(_ index: Int) -> CGFloat {
            inset + pitch * CGFloat(index)
        }

        /// Largeur couverte par les `lit` premiers carrés.
        func span(_ lit: Int) -> CGFloat {
            lit > 0 ? pitch * CGFloat(lit) - Theme.dotGap : 0
        }

        func count(for fraction: Double) -> Int {
            Int((min(max(fraction, 0), 1) * Double(count)).rounded())
        }

        func index(for fraction: Double) -> Int {
            min(max(Int(fraction * Double(count)), 0), count - 1)
        }
    }
}

/// Quand la largeur change (le panneau s'ouvre ou se referme), les carrés se
/// posent directement à leur place définitive : seule la découpe suit le
/// ressort de la forme et les révèle. Sans cela, chaque carré glisserait avec
/// son propre retard.
///
/// Au survol, seule la hauteur change : la rangée descend alors d'un bloc avec
/// le ressort, comme le trait, au lieu de sauter à sa place.
///
/// Posé à l'extérieur des `.animation(_:value:)` de la rangée : il efface
/// l'animation héritée de la forme, puis celles-ci remettent la leur quand le
/// remplissage ou la couleur changent vraiment.
private struct Settled: ViewModifier {
    var width: CGFloat

    func body(content: Content) -> some View {
        content.transaction(value: width) { $0.animation = nil }
    }
}

/// Pose la rangée au bas de la forme et la fait tailler par ses coins, avant
/// que la lueur ne s'applique : comme la barre, le trait reste dans le notch
/// et son halo déborde librement.
private struct DotsInNotch: ViewModifier {
    var size: CGSize
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.bottom, Theme.dotInset)
            .frame(width: size.width, height: size.height, alignment: .bottomLeading)
            .clipShape(NotchShape(cornerRadius: cornerRadius, tuck: 0))
    }
}
