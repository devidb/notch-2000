//
//  Ext+NSScreen.swift
//  Notch2000
//
//  Dérivé de NotchDrop (MIT, Lakr Aream) : mesure du notch physique et choix de l'écran.
//

import Cocoa

extension NSScreen {
    /// Taille de la découpe physique, ou `.zero` sur un écran qui n'en a pas.
    var notchSize: CGSize {
        guard safeAreaInsets.top > 0 else { return .zero }
        let notchHeight = safeAreaInsets.top
        let fullWidth = frame.width
        let leftPadding = auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = auxiliaryTopRightArea?.width ?? 0
        guard leftPadding > 0, rightPadding > 0 else { return .zero }
        let notchWidth = fullWidth - leftPadding - rightPadding
        return CGSize(width: notchWidth, height: notchHeight)
    }

    var menuBarHeight: CGFloat {
        frame.maxY - visibleFrame.maxY
    }

    var isBuildinDisplay: Bool {
        let screenNumberKey = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
        guard let id = deviceDescription[screenNumberKey],
              let rid = (id as? NSNumber)?.uint32Value,
              CGDisplayIsBuiltin(rid) == 1
        else { return false }
        return true
    }

    static var buildin: NSScreen? {
        screens.first { $0.isBuildinDisplay }
    }
}
