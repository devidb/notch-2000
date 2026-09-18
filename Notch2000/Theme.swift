//
//  Theme.swift
//  Notch2000
//
//  Jetons visuels repris du canvas de design Notch2000.
//

import SwiftUI

enum Theme {
    // MARK: - Couleurs

    /// Teinte d'accent de Claude, 38,8° en oklch. La clarté est montée de 0,67
    /// à 0,76 : sur 2 pt de haut, l'orange d'origine paraissait éteint.
    static let clay = Color(red: 0xFE / 255, green: 0x8E / 255, blue: 0x69 / 255)
    /// Même teinte, un cran plus clair encore, pour la pointe du dégradé.
    static let clayVivid = Color(red: 0xFF / 255, green: 0xA3 / 255, blue: 0x85 / 255)
    /// La teinte d'origine, conservée pour les textes où elle reste lisible.
    static let clayDeep = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
    /// Variante claire utilisée par le balayage de synchronisation.
    static let scanner = Color(red: 0xF0 / 255, green: 0xA5 / 255, blue: 0x8A / 255)
    /// Blanc cassé du design, base de tous les gris de texte.
    static let ivory = Color(red: 0xFA / 255, green: 0xF9 / 255, blue: 0xF5 / 255)
    /// Point repère du temps écoulé, volontairement plus chaud que le blanc pur.
    static let kitt = Color(red: 0xFF / 255, green: 0xF6 / 255, blue: 0xEE / 255)

    static func ivory(_ opacity: Double) -> Color { ivory.opacity(opacity) }

    // Palette de consommation : trois teintes construites sur la même base
    // perceptuelle que l'orange de Claude, avec la clarté propre à chaque teinte
    // et le chroma poussé au maximum affichable, d'où l'éclat.

    /// Moins de la moitié consommée.
    static let mint = Color(red: 0x08 / 255, green: 0xB7 / 255, blue: 0x85 / 255)
    static let mintVivid = Color(red: 0x0D / 255, green: 0xC9 / 255, blue: 0x92 / 255)
    /// Entre la moitié et le seuil d'alerte.
    static let amber = Color(red: 0xE3 / 255, green: 0x9F / 255, blue: 0x02 / 255)
    static let amberVivid = Color(red: 0xF7 / 255, green: 0xAE / 255, blue: 0x05 / 255)
    /// Au delà du seuil d'alerte.
    static let ember = Color(red: 0xEB / 255, green: 0x22 / 255, blue: 0x04 / 255)
    static let emberVivid = Color(red: 0xFE / 255, green: 0x44 / 255, blue: 0x2B / 255)

    /// Les deux couleurs de la barre : son départ et sa pointe.
    static func barColors(_ palette: BarPalette, percent: Double) -> (base: Color, vivid: Color) {
        switch palette {
        case .claude:
            return (clay, clayVivid)
        case .consumption:
            if percent >= consumptionHighThreshold { return (ember, emberVivid) }
            if percent >= consumptionMidThreshold { return (amber, amberVivid) }
            return (mint, mintVivid)
        }
    }

    /// Bascule vers l'ambre.
    static let consumptionMidThreshold: Double = 50
    /// Bascule vers la braise.
    static let consumptionHighThreshold: Double = 80

    /// Fond des surfaces de la fenêtre de réglages.
    static let panelBackground = Color(red: 0x23 / 255, green: 0x22 / 255, blue: 0x20 / 255)
    static let windowBackground = Color(red: 0x1F / 255, green: 0x1E / 255, blue: 0x1C / 255)

    // MARK: - Métriques du notch

    /// Débord de la forme sous la découpe physique : la barre vit dans ces points.
    static let shapeOverhang: CGFloat = 4
    /// Élargissement total au survol, soit 42 pt par oreille : de quoi loger
    /// les chiffres sans les serrer contre la découpe.
    static let hoverWidening: CGFloat = 84
    /// Taille du panneau, seul écran de réglages de l'app.
    static let panelSize = CGSize(width: 340, height: 388)

    /// Rayon des coins bas, accordé à l'œil sur celui de la découpe physique :
    /// plus petit, la forme paraît pointue à côté du notch.
    static let cornerRadiusClosed: CGFloat = 13
    static let cornerRadiusPanel: CGFloat = 22

    /// Épaisseur de la barre de session.
    static let barHeight: CGFloat = 2
    /// Largeur du repère KITT posé sur la barre.
    static let kittWidth: CGFloat = 4
    /// Le repère est bien plus petit que la barre : sans surcroît d'intensité,
    /// le halo de celle-ci l'avale. Le gain porte surtout sur l'opacité, pour
    /// concentrer l'éclat plutôt que d'élargir un halo qui noierait la barre.
    static let kittGlowOpacityBoost: Double = 1.7
    static let kittGlowRadiusBoost: Double = 1.2
    /// Raccord concave vers la barre de menus. Il n'a de sens que lorsque la
    /// forme déborde du notch ; sinon il dessine deux ailes noires de part et
    /// d'autre de la découpe.
    static let tuck: CGFloat = 6

    // MARK: - Typographie

    /// Chiffres des oreilles : discrets mais lisibles d'un coup d'œil.
    static let inlineDigits = Font.system(size: 9.5, weight: .regular, design: .monospaced)
        .monospacedDigit()

    // Le panneau tient sur trois tailles et deux opacités : au delà,
    // l'empilement de variantes se lit comme du désordre.

    /// Les deux valeurs du haut du panneau.
    static let panelDisplay = Font.system(size: 24, weight: .light).monospacedDigit()
    /// Libellés des rangées et des contrôles.
    static let panelBody = Font.system(size: 11)
    /// Légendes et pied de panneau.
    static let panelCaption = Font.system(size: 9)

    /// Opacité du texte secondaire, la seule nuance admise avec le texte plein.
    static let secondaryOpacity: Double = 0.5

    /// Fondu des chiffres, découplé du ressort de la forme.
    static let digitsFade = Animation.easeInOut(duration: 0.16)

    // MARK: - Animations

    /// Changement de forme (repos, survol, panneau) : 320 ms avec un léger rebond.
    static let shapeAnimation = Animation.interpolatingSpring(mass: 0.4, stiffness: 180, damping: 14)
    /// Progression de la barre : lente et sans rebond.
    static let fillAnimation = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.6)
    /// Balayage pendant la synchronisation.
    static let scanAnimation = Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: true)

    // MARK: - Seuils

    /// Au delà de ce pourcentage, les chiffres passent à la couleur de la barre.
    static let alertThreshold: Double = 85
}
