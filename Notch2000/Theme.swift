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

    /// Encre du site vitrine : le texte posé sur un bloc orange.
    static let ink = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255)

    // MARK: - Blocs en relief
    //
    // Chaque contrôle du panneau est un petit bloc : une face éclairée par le
    // haut, posée sur une tranche sombre de quelques points. Enfoncer le bloc,
    // c'est faire descendre la face sur sa tranche. Trois jeux de couleurs
    // suffisent : neutre, orange, et le creux où rien ne dépasse.

    static let blockTop = Color(red: 0x3C / 255, green: 0x39 / 255, blue: 0x35 / 255)
    static let blockBottom = Color(red: 0x2A / 255, green: 0x28 / 255, blue: 0x25 / 255)
    static let blockEdge = Color(red: 0x12 / 255, green: 0x11 / 255, blue: 0x10 / 255)

    static let clayTop = Color(red: 0xF2 / 255, green: 0x93 / 255, blue: 0x70 / 255)
    static let clayBottom = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
    static let clayEdge = Color(red: 0x7E / 255, green: 0x3E / 255, blue: 0x28 / 255)

    /// Fond des creux : pistes d'interrupteur, rail des segments, écran d'aide.
    static let hollow = Color(red: 0x16 / 255, green: 0x15 / 255, blue: 0x14 / 255)

    /// Épaisseur de la tranche sous les blocs, et rayon de leurs coins. Le rayon
    /// est volontairement court : des boutons presque carrés, comme sur le site.
    static let blockDepth: CGFloat = 3
    static let blockRadius: CGFloat = 5

    // MARK: - Métriques du notch

    /// Débord de la forme sous la découpe physique : la barre vit dans ces points.
    static let shapeOverhang: CGFloat = 4
    /// Débord en mode carrés : la rangée est plus haute que le trait.
    static let dotsOverhang: CGFloat = 10

    static func overhang(_ style: BarStyle) -> CGFloat {
        style == .dots ? dotsOverhang : shapeOverhang
    }

    /// Carrés de la jauge : côté, espace minimal entre deux, retrait du bas.
    static let dotSize: CGFloat = 4
    static let dotGap: CGFloat = 2
    static let dotInset: CGFloat = 4
    /// Carré éteint : juste assez visible pour lire la graduation.
    static let dotOff = Color(red: 0x1C / 255, green: 0x1B / 255, blue: 0x19 / 255)
    /// Élargissement total au survol, soit 42 pt par oreille : de quoi loger
    /// les chiffres sans les serrer contre la découpe.
    static let hoverWidening: CGFloat = 84
    /// Taille du panneau, seul écran de réglages de l'app : deux valeurs, deux
    /// rangées de touches et une ligne d'aide.
    static let panelSize = CGSize(width: 360, height: 232)

    /// Touches du panneau : hauteur de la face, écart entre deux touches.
    static let keyHeight: CGFloat = 40
    /// Rayon des touches : celui du bouton Télécharger du site.
    static let keyRadius: CGFloat = 7
    static let keySpacing: CGFloat = 8
    /// Durée d'appui pour quitter : assez longue pour qu'un clic ne suffise pas.
    static let quitHoldDuration: Double = 0.8
    /// Rouge du bouton Quitter pendant l'appui.
    static let quitFill = emberVivid

    /// Bandeau ajouté sous le panneau quand une mise à jour a quelque chose à
    /// dire. Le notch se déplie d'autant : les réglages restent visibles, rien
    /// ne les remplace.
    static let updateBandHeight: CGFloat = 96

    /// Le panneau dans son état le plus grand. C'est lui qui dimensionne le
    /// conteneur immobile de la vue racine.
    static let panelMaxSize = CGSize(width: panelSize.width, height: panelSize.height + updateBandHeight)

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

    /// Police de marque, la même que le site vitrine.
    ///
    /// Elle est embarquée dans le bundle et déclarée par `ATSApplicationFontsPath`.
    /// Si elle venait à manquer, `Font.custom` retombe seul sur la police système :
    /// le panneau reste lisible, il perd juste son accent.
    ///
    /// Michroma est large et sans chasse fixe : on la réserve au wordmark, aux
    /// deux grandes valeurs et aux libellés de boutons. Les rangées de réglages
    /// restent en San Francisco, seule police vraiment lisible à 11 points.
    static func racing(_ size: CGFloat) -> Font { .custom("Michroma-Regular", size: size) }

    // Le panneau tient sur trois tailles et deux opacités : au delà,
    // l'empilement de variantes se lit comme du désordre.

    /// Les deux valeurs du haut du panneau : fines, en chiffres à chasse fixe.
    static let panelDisplay = Font.system(size: 24, weight: .light).monospacedDigit()
    /// Libellé de touche et ligne d'aide du panneau.
    static let panelMono = Font.system(size: 9, weight: .regular, design: .monospaced)
    /// Le nom de l'app, en tout petit au dessus des valeurs.
    static let panelWordmark = racing(9)
    /// Libellés des boutons et des segments.
    static let panelAction = racing(8)
    /// Libellés des rangées et des contrôles.
    static let panelBody = Font.system(size: 11)
    /// Légendes et pied de panneau.
    static let panelCaption = Font.system(size: 9)
    /// Ligne d'aide : elle remplace les infobulles, qui ne s'affichent pas au
    /// dessus d'une fenêtre sans barre de titre posée sur la barre de menus.
    static let panelHint = Font.system(size: 9.5)

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
