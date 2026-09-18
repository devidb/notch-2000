//
//  NotchShape.swift
//  Notch2000
//
//  Forme noire prolongeant la découpe physique : coins bas arrondis et raccords
//  concaves qui rejoignent la barre de menus.
//

import SwiftUI

struct NotchShape: Shape {
    /// Rayon des deux coins bas.
    var cornerRadius: CGFloat
    /// Rayon des raccords concaves qui fondent la forme dans la barre de menus.
    var tuck: CGFloat = 6

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Les raccords débordent de chaque côté ; le corps occupe le reste.
        let body = rect.insetBy(dx: tuck, dy: 0)
        let radius = min(cornerRadius, body.width / 2, body.height)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: body.minX, y: rect.minY + tuck),
            control: CGPoint(x: body.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: body.minX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: body.minX + radius, y: rect.maxY),
            control: CGPoint(x: body.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: body.maxX - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: body.maxX, y: rect.maxY - radius),
            control: CGPoint(x: body.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: body.maxX, y: rect.minY + tuck))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: body.maxX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
