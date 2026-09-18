//
//  QuickPanelView.swift
//  Notch2000
//
//  Seul écran de réglages de l'app : il s'ouvre dans le notch, au clic.
//
//  Pas de liste de rangées : deux valeurs en tête, puis une grille de touches
//  en relief (voir `Chunky.swift`) qui occupe toute la largeur. Chaque touche
//  ne porte qu'un glyphe, et ce glyphe montre l'état du réglage : il se
//  transforme quand on appuie. Le seul texte est une ligne d'aide, sous la
//  grille, qui nomme la touche survolée et raconte la connexion au repos.
//
//  La barre du notch, au bas du panneau, sert d'aperçu : elle suit chaque
//  réglage en direct.
//

import AppKit
import SwiftUI

struct QuickPanelView: View {
    @ObservedObject var vm: NotchViewModel

    /// Nom de la touche survolée. À vide, la ligne parle de la connexion.
    @State private var hint: String?
    /// Pourcentage affiché : il part de zéro à l'ouverture et compte jusqu'à sa valeur.
    @State private var shownPercent: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            header

            // Deux rangées franches plutôt qu'une grille paresseuse : celle ci
            // reconstruit ses cellules à chaque redessin, ce qui jette les
            // animations des glyphes avant qu'elles ne soient jouées.
            VStack(spacing: Theme.keySpacing) {
                HStack(spacing: Theme.keySpacing) { displayKeys }
                HStack(spacing: Theme.keySpacing) { systemKeys }
            }
            .padding(.top, 16)

            hintLine
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 44)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { countUp() }
        .onChange(of: vm.usage.percent) { countUp() }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            if vm.usage.isSyncing {
                Text("···")
                    .foregroundStyle(headlineColor)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(shownPercent.rounded()))")
                        .contentTransition(.numericText(value: shownPercent))
                    Text("%")
                        .font(Theme.panelDisplayUnit)
                }
                .foregroundStyle(headlineColor)
            }

            Spacer(minLength: 12)

            // Mêmes couleurs que les chiffres du notch : la barre pour le quota,
            // le repère pour l'heure.
            Text(vm.usage.renewalLabel(vm.settings.renewalDisplay))
                .contentTransition(.numericText())
                .foregroundStyle(Theme.kitt.hdr(digitsStops))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.settings.renewalDisplay)
        }
        .font(Theme.panelDisplay)
        .lineLimit(1)
    }

    private var headlineColor: Color {
        Theme.barColors(vm.settings.barPalette, percent: vm.usage.percent).base.hdr(digitsStops)
    }

    /// Chiffres poussés en HDR avec la jauge, un cran en dessous.
    private var digitsStops: Double {
        vm.settings.hdrEnabled ? Theme.digitsHDRStops : 0
    }

    /// Le pourcentage repart de zéro à chaque ouverture : les chiffres défilent
    /// jusqu'à la valeur, comme un compteur.
    private func countUp() {
        shownPercent = 0
        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.9)) {
                shownPercent = vm.usage.percent
            }
        }
    }

    // MARK: - Touches

    /// Première rangée : ce que montre la barre.
    @ViewBuilder
    private var displayKeys: some View {
        let settings = vm.settings

        PanelKey(
            label: String(localized: "Barre") + " · " + (settings.barStyle == .dots ? String(localized: "carrés") : String(localized: "ligne")),
            isOn: false,
            action: { settings.barStyle = settings.barStyle == .dots ? .line : .dots },
            onHover: hover
        ) {
            BarStyleGlyph(style: settings.barStyle)
        }

        PanelKey(
            label: String(localized: "Couleur") + " · " + (settings.barPalette == .claude ? "Clay" : String(localized: "consommation")),
            isOn: false,
            action: { settings.barPalette = settings.barPalette == .claude ? .consumption : .claude },
            onHover: hover
        ) {
            PaletteGlyph(palette: settings.barPalette)
        }

        PanelKey(
            label: String(localized: "Lueur") + " · " + (settings.glowIntensity == .soft ? String(localized: "douce") : String(localized: "intense")),
            isOn: false,
            action: { settings.glowIntensity = settings.glowIntensity == .soft ? .strong : .soft },
            onHover: hover
        ) {
            GlowGlyph(isStrong: settings.glowIntensity == .strong)
        }

        PanelKey(
            label: String(localized: "Éclat HDR"),
            isOn: settings.hdrEnabled,
            action: { settings.hdrEnabled.toggle() },
            onHover: hover
        ) {
            HDRGlyph(isOn: settings.hdrEnabled)
        }

        PanelKey(
            label: String(localized: "Repère de temps"),
            isOn: settings.kittEnabled,
            action: { settings.kittEnabled.toggle() },
            onHover: hover
        ) {
            KittGlyph(isOn: settings.kittEnabled)
        }

    }

    /// Seconde rangée : les chiffres, le fonctionnement, l'app.
    @ViewBuilder
    private var systemKeys: some View {
        let settings = vm.settings

        PanelKey(
            label: String(localized: "Chiffres") + " · " + (settings.digitsAlwaysVisible ? String(localized: "toujours") : String(localized: "au survol")),
            isOn: settings.digitsAlwaysVisible,
            action: { settings.digitsAlwaysVisible.toggle() },
            onHover: hover
        ) {
            DigitsGlyph(isOn: settings.digitsAlwaysVisible)
        }

        PanelKey(
            label: String(localized: "Renouvellement") + " · " + settings.renewalDisplay.label,
            isOn: false,
            action: { settings.renewalDisplay = settings.renewalDisplay == .target ? .countdown : .target },
            onHover: hover
        ) {
            RenewalGlyph(display: settings.renewalDisplay)
        }

        PanelKey(
            label: String(localized: "Relire les identifiants"),
            isOn: false,
            action: { vm.usage.reauthenticate() },
            onHover: hover
        ) {
            KeyringGlyph(isSyncing: vm.usage.isSyncing)
        }

        PanelKey(
            label: settings.launchAtLoginNeedsApproval
                ? String(localized: "À autoriser dans les Réglages Système")
                : String(localized: "Ouvrir à la connexion"),
            isOn: settings.launchAtLogin,
            action: {
                if settings.launchAtLoginNeedsApproval {
                    settings.revealLoginItems()
                } else {
                    settings.launchAtLogin.toggle()
                }
            },
            onHover: hover
        ) {
            IgnitionGlyph(isOn: settings.launchAtLogin)
        }

        QuitKey(label: String(localized: "Maintenir pour quitter"), onHover: hover)
    }

    /// Le pointeur passe souvent d'une touche à sa voisine : une sortie n'efface
    /// que le nom qu'elle avait elle-même posé, sinon l'ordre des deux
    /// notifications déciderait de ce qui reste affiché.
    private func hover(_ label: String, _ hovering: Bool) {
        if hovering {
            hint = label
        } else if hint == label {
            hint = nil
        }
    }

    // MARK: - Ligne d'aide

    /// Hauteur fixe de deux lignes : le panneau ne saute pas au passage du pointeur.
    /// Au repos, elle raconte la connexion ; un clic relit le quota.
    private var hintLine: some View {
        Button {
            vm.usage.refreshNow()
        } label: {
            HStack(alignment: .top, spacing: 7) {
                if hint == nil {
                    Rectangle()
                        .fill(accountConnected ? Theme.mint : Theme.ivory(0.3))
                        .frame(width: 5, height: 5)
                        .padding(.top, 3)
                }
                Text(hint ?? accountDetail)
                    .font(Theme.panelMono)
                    .foregroundStyle(Theme.ivory(hint == nil ? 0.42 : 0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .id(hint ?? "")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 3)),
                        removal: .opacity
                    ))
            }
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: hint)
    }

    private var accountConnected: Bool {
        if case .unavailable = vm.usage.state { return false }
        return true
    }

    /// Ce que la ligne raconte au repos : d'où vient le quota, ou pourquoi il manque.
    private var accountDetail: String {
        switch vm.usage.state {
        case .syncing:
            return String(localized: "Lecture du quota auprès d'Anthropic…")
        case .live:
            guard let source = vm.usage.credentialSource else {
                return String(localized: "Quota simulé par les variables d'environnement de mise au point.")
            }
            return String(localized: "Quota lu depuis la session Claude Code (\(source.label)).")
        case let .unavailable(reason):
            return reason
        }
    }
}

// MARK: - Touche

/// Une touche du panneau : un bloc en relief, orange quand le réglage est actif.
/// Chaque appui la fait descendre sur sa tranche et y fait passer un reflet,
/// le même que sur le bouton Télécharger du site.
private struct PanelKey<Glyph: View>: View {
    var label: String
    var isOn: Bool
    var action: () -> Void
    var onHover: (String, Bool) -> Void
    @ViewBuilder var glyph: () -> Glyph

    @State private var flashes = 0
    @State private var isHovering = false

    var body: some View {
        Button {
            // Le changement passe par une transaction animée : sans elle, les
            // symboles qui se remplacent (la coche, le soleil) sauteraient.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { action() }
            flashes += 1
        } label: {
            glyph()
                .foregroundStyle(isOn ? Theme.ink : Theme.ivory(isHovering ? 1 : 0.8))
                .frame(maxWidth: .infinity)
                .frame(height: Theme.keyHeight)
                .overlay { Sheen(trigger: flashes, strength: isOn ? 0.9 : 0.35) }
                .clipShape(RoundedRectangle(cornerRadius: Theme.keyRadius, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(KeyStyle(isOn: isOn))
        .onHover { hovering in
            isHovering = hovering
            onHover(label, hovering)
        }
        .animation(.easeOut(duration: 0.16), value: isOn)
        .accessibilityLabel(label)
    }
}

private struct KeyStyle: ButtonStyle {
    var isOn: Bool

    /// Une seule branche, aux couleurs variables : un `if` entre deux blocs
    /// donnerait deux vues distinctes, et SwiftUI jetterait le glyphe, son
    /// animation et son reflet à chaque bascule.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(ChunkyFace(
                top: isOn ? Theme.clayTop : Theme.blockTop,
                bottom: isOn ? Theme.clayBottom : Theme.blockBottom,
                edge: isOn ? Theme.clayEdge : Theme.blockEdge,
                isPressed: configuration.isPressed,
                radius: Theme.keyRadius
            ))
    }
}

/// Reflet qui traverse une touche de gauche à droite à chaque appui.
private struct Sheen: View {
    var trigger: Int
    var strength: Double

    @State private var phase: CGFloat = -1.3

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.28),
                    .init(color: .white.opacity(strength * 0.4), location: 0.42),
                    .init(color: .white.opacity(strength), location: 0.5),
                    .init(color: .white.opacity(strength * 0.4), location: 0.58),
                    .init(color: .clear, location: 0.72),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width)
            .offset(x: phase * proxy.size.width)
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { phase = -1.3 }
            DispatchQueue.main.async {
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.75)) { phase = 1.3 }
            }
        }
    }
}

// MARK: - Quitter

/// Quitter demande un appui maintenu : la touche se remplit de rouge par le bas
/// et l'app ne se ferme qu'une fois pleine. Relâcher avant annule.
private struct QuitKey: View {
    var label: String
    var onHover: (String, Bool) -> Void

    @State private var holding = false
    @State private var progress: CGFloat = 0
    @State private var pending: Task<Void, Never>?
    @State private var hovers = 0

    var body: some View {
        Image(systemName: "power")
            .font(.system(size: 15, weight: .semibold))
            .symbolEffect(.bounce, value: hovers)
            .foregroundStyle(Theme.ivory(holding ? 1 : 0.8))
            .frame(maxWidth: .infinity)
            .frame(height: Theme.keyHeight)
            .background(alignment: .bottom) {
                GeometryReader { proxy in
                    Theme.quitFill
                        .frame(height: proxy.size.height * progress)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.keyRadius, style: .continuous))
            .contentShape(Rectangle())
            .chunky(pressed: holding, radius: Theme.keyRadius)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in start() }
                    .onEnded { _ in cancel() }
            )
            .onHover { hovering in
                if hovering { hovers += 1 }
                onHover(label, hovering)
            }
            .accessibilityElement()
            .accessibilityLabel(String(localized: "Quitter Notch2000"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { NSApp.terminate(nil) }
    }

    private func start() {
        guard !holding else { return }
        holding = true
        withAnimation(.linear(duration: Theme.quitHoldDuration)) { progress = 1 }
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Theme.quitHoldDuration))
            guard !Task.isCancelled, holding else { return }
            NSApp.terminate(nil)
        }
    }

    private func cancel() {
        holding = false
        pending?.cancel()
        pending = nil
        withAnimation(.easeOut(duration: 0.18)) { progress = 0 }
    }
}

// MARK: - Glyphes

/// Le trait se découpe en carrés, et les carrés se recollent en trait.
struct BarStyleGlyph: View {
    var style: BarStyle

    private let squares = 5

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .frame(width: 30, height: 2)
                .scaleEffect(x: style == .line ? 1 : 0.01, anchor: .leading)
                .opacity(style == .line ? 1 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: style)

            HStack(spacing: 2.5) {
                ForEach(0..<squares, id: \.self) { index in
                    Rectangle()
                        .frame(width: 4, height: 4)
                        .scaleEffect(style == .dots ? 1 : 0.01)
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.55)
                                .delay(Double(style == .dots ? index : squares - 1 - index) * 0.04),
                            value: style
                        )
                }
            }
        }
        .frame(width: 30, height: 8)
    }
}

/// Un compte-tours : trois zones, toutes orange ou menthe, ambre et braise.
/// L'aiguille repart de la gauche à chaque changement.
struct PaletteGlyph: View {
    var palette: BarPalette

    private var zones: [Color] {
        palette == .claude
            ? [Theme.clay, Theme.clay, Theme.clay]
            : [Theme.mintVivid, Theme.amberVivid, Theme.emberVivid]
    }

    private let bounds: [(CGFloat, CGFloat)] = [(0.5, 0.69), (0.705, 0.84), (0.855, 1)]

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .trim(from: bounds[index].0, to: bounds[index].1)
                    .stroke(zones[index], style: StrokeStyle(lineWidth: 3))
                    .frame(width: 18, height: 18)
                    .frame(height: 9, alignment: .top)
                    .animation(.easeOut(duration: 0.22).delay(Double(index) * 0.09), value: palette)
            }

            Capsule()
                .frame(width: 1.8, height: 8)
                .offset(y: -4)
                .keyframeAnimator(initialValue: 0.0, trigger: palette) { needle, swing in
                    needle.rotationEffect(.degrees(-38 + swing), anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-60, duration: 0.01)
                        SpringKeyframe(0, duration: 0.6, spring: .bouncy)
                    }
                }

            Circle()
                .frame(width: 3.5, height: 3.5)
                .offset(y: 1.75)
        }
        .frame(width: 22, height: 14, alignment: .bottom)
    }
}

/// Une mini-barre et son repère : le point tombe dessus, puis glisse en place.
struct KittGlyph: View {
    var isOn: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().frame(width: 30, height: 2).opacity(0.35)
            Rectangle().frame(width: 12, height: 2)
            Rectangle()
                .frame(width: 5, height: 6)
                .scaleEffect(isOn ? 1 : 0.01)
                .opacity(isOn ? 1 : 0)
                .keyframeAnimator(initialValue: 0.0, trigger: isOn) { dot, shift in
                    dot.offset(x: 19 + shift)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(isOn ? -19 : 0, duration: 0.01)
                        SpringKeyframe(0, duration: 0.5, spring: .bouncy)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isOn)
        }
        .frame(width: 30, height: 8)
    }
}

/// Le pourcentage, net quand il reste affiché, estompé quand il attend le survol.
/// Il défile vers le haut à chaque changement, comme un compteur mécanique.
struct DigitsGlyph: View {
    var isOn: Bool

    var body: some View {
        Text("29%")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .opacity(isOn ? 1 : 0.45)
            .keyframeAnimator(initialValue: 0.0, trigger: isOn) { digits, rise in
                digits.offset(y: rise)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(12, duration: 0.01)
                    SpringKeyframe(0, duration: 0.45, spring: .bouncy)
                }
            }
            .frame(height: 16)
            .clipped()
    }
}

/// Ouvrir à la connexion : la session de l'utilisateur. La coche est dessinée
/// à part et non par un symbole de remplacement, sinon macOS l'échange d'un
/// coup sans transition.
struct IgnitionGlyph: View {
    var isOn: Bool

    var body: some View {
        Image(systemName: "person.crop.circle")
            .font(.system(size: 17, weight: .medium))
            .overlay(alignment: .bottomTrailing) {
                // Une coche nue : un badge plein prendrait la couleur du texte
                // et deviendrait un disque sombre sur la face orange.
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .black))
                    .scaleEffect(isOn ? 1 : 0.2)
                    .opacity(isOn ? 1 : 0)
                    .offset(x: 5, y: 3)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isOn)
    }
}

/// Éclat HDR : les trois lettres s'allument, comme un voyant, et rebondissent.
struct HDRGlyph: View {
    var isOn: Bool

    var body: some View {
        Text(verbatim: "HDR")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .opacity(isOn ? 1 : 0.45)
            .scaleEffect(isOn ? 1 : 0.9)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isOn)
    }
}

/// Lueur : un soleil dont les rayons s'étirent en tournant.
struct GlowGlyph: View {
    var isStrong: Bool

    var body: some View {
        ZStack {
            Circle()
                .frame(width: isStrong ? 8 : 6.5, height: isStrong ? 8 : 6.5)
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .frame(width: 1.8, height: isStrong ? 4 : 2.4)
                    .offset(y: isStrong ? -8.5 : -6.5)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            .rotationEffect(.degrees(isStrong ? 0 : -22))
        }
        .frame(width: 22, height: 22)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isStrong)
    }
}

/// L'horloge fait un demi-tour sur elle-même et retombe en sablier, et inversement.
struct RenewalGlyph: View {
    var display: RenewalDisplay

    private var isTarget: Bool { display == .target }

    var body: some View {
        ZStack {
            Image(systemName: "clock")
                .opacity(isTarget ? 1 : 0)
                .scaleEffect(isTarget ? 1 : 0.6)
            Image(systemName: "hourglass")
                .opacity(isTarget ? 0 : 1)
                .scaleEffect(isTarget ? 0.6 : 1)
        }
        .font(.system(size: 16, weight: .medium))
        .rotationEffect(.degrees(isTarget ? 0 : 180))
        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: display)
    }
}

/// Relire les identifiants : le trousseau fait un tour sur lui même, et
/// recommence tant que la lecture du quota est en cours.
struct KeyringGlyph: View {
    var isSyncing: Bool

    @State private var turns = 0

    var body: some View {
        Image(systemName: "key.horizontal")
            .font(.system(size: 16, weight: .medium))
            .rotationEffect(.degrees(Double(turns) * 360))
            .animation(.spring(response: 0.75, dampingFraction: 0.6), value: turns)
            .onChange(of: isSyncing) { _, syncing in
                if syncing { turns += 1 }
            }
    }
}
