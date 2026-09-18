//
//  NotchViewController.swift
//  Notch2000
//
//  Dérivé de NotchDrop (MIT, Lakr Aream).
//

import AppKit
import SwiftUI

final class NotchViewController: NSHostingController<NotchRootView> {
    init(_ vm: NotchViewModel) {
        super.init(rootView: NotchRootView(vm: vm))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }
}
