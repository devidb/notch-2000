//
//  Chunky.swift
//  Notch2000
//
//  Les contrôles en relief du panneau, dans l'esprit du site vitrine.
//
//  Un seul principe, décliné partout : une face presque carrée, éclairée par le
//  haut, posée sur une tranche sombre de quelques points. Appuyer fait descendre
//  la face sur sa tranche ; rien d'autre ne bouge, et la mise en page réserve
//  toujours la hauteur de la tranche pour que rien ne saute.
//

import SwiftUI

/// Pose un contenu sur un bloc en relief.
struct ChunkyFace: ViewModifier {
    var top: Color
    var bottom: Color
    var edge: Color
    /// Enfoncé : la face descend de toute l'épaisseur de sa tranche.
    var isPressed: Bool = false
    var depth: CGFloat = Theme.blockDepth
    var radius: CGFloat = Theme.blockRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .background {
                shape
                    .fill(
                        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
                    )
                    // L'arête éclairée du haut fait tout le relief : sans elle,
                    // la face n'est qu'un rectangle de couleur.
                    .overlay {
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [Theme.ivory(0.28), Theme.ivory(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    }
            }
            // `offset` ne déplace que le dessin : la tranche posée juste après
            // reste donc en place pendant que la face lui descend dessus.
            .offset(y: isPressed ? depth : 0)
            .background(alignment: .top) {
                shape.fill(edge).offset(y: depth)
            }
            // Hauteur réservée à la tranche, sinon le bloc rogne son voisin.
            .padding(.bottom, depth)
            .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

extension View {
    /// Bloc neutre, celui de la plupart des contrôles.
    func chunky(pressed: Bool = false, radius: CGFloat = Theme.blockRadius) -> some View {
        modifier(ChunkyFace(
            top: Theme.blockTop,
            bottom: Theme.blockBottom,
            edge: Theme.blockEdge,
            isPressed: pressed,
            radius: radius
        ))
    }

    /// Bloc orange, réservé à l'action principale et aux segments choisis.
    func chunkyClay(pressed: Bool = false, radius: CGFloat = Theme.blockRadius) -> some View {
        modifier(ChunkyFace(
            top: Theme.clayTop,
            bottom: Theme.clayBottom,
            edge: Theme.clayEdge,
            isPressed: pressed,
            radius: radius
        ))
    }

    /// Creux : un renfoncement où l'on loge ce qui n'est pas cliquable.
    func hollowed(radius: CGFloat = Theme.blockRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            shape
                .fill(Theme.hollow)
                // Ombre portée à l'intérieur du bord haut : l'inverse de l'arête
                // éclairée des blocs, donc l'inverse du relief.
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.black.opacity(0.8), Theme.ivory(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
        }
    }
}

/// Bouton en relief. La teinte orange est réservée à l'action principale.
struct ChunkyButtonStyle: ButtonStyle {
    enum Tone { case neutral, clay }

    var tone: Tone = .neutral
    var horizontal: CGFloat = 12
    var vertical: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .foregroundStyle(tone == .clay ? Theme.ink : Theme.ivory(0.9))
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)

        switch tone {
        case .neutral:
            label.chunky(pressed: configuration.isPressed)
        case .clay:
            label.chunkyClay(pressed: configuration.isPressed)
        }
    }
}

/// Interrupteur : un petit bloc qui glisse d'un bout à l'autre de son creux.
struct ChunkySwitch: View {
    var isOn: Bool

    private let trackWidth: CGFloat = 32
    private let trackHeight: CGFloat = 18
    private let knob: CGFloat = 14

    var body: some View {
        Color.clear
            .frame(width: trackWidth, height: trackHeight)
            .hollowed(radius: 4)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Color.clear
                    .frame(width: knob, height: knob - Theme.blockDepth)
                    .modifier(ChunkyFace(
                        top: isOn ? Theme.clayTop : Theme.blockTop,
                        bottom: isOn ? Theme.clayBottom : Theme.blockBottom,
                        edge: isOn ? Theme.clayEdge : Theme.blockEdge,
                        radius: 3
                    ))
                    .padding(.horizontal, 2)
            }
            .animation(.easeInOut(duration: 0.16), value: isOn)
    }
}

/// Sélecteur à segments : les options sont des blocs alignés dans un creux,
/// celui qui est retenu prend l'orange.
struct ChunkySegmented<Option: Hashable, Content: View>: View {
    var options: [Option]
    var selection: Option
    var select: (Option) -> Void
    @ViewBuilder var content: (Option) -> Content

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { select(option) } label: {
                    content(option)
                        .foregroundStyle(selected ? Theme.ink : Theme.ivory(0.65))
                        .frame(minWidth: 28)
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SegmentStyle(selected: selected))
            }
        }
        .padding(3)
        .hollowed(radius: 7)
    }

    private struct SegmentStyle: ButtonStyle {
        var selected: Bool

        func makeBody(configuration: Configuration) -> some View {
            if selected {
                configuration.label.chunkyClay(pressed: configuration.isPressed, radius: 4)
            } else {
                configuration.label.chunky(pressed: configuration.isPressed, radius: 4)
            }
        }
    }
}
