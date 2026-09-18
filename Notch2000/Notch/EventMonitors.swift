//
//  EventMonitors.swift
//  Notch2000
//
//  Dérivé de NotchDrop (MIT, Lakr Aream), réduit aux deux événements utiles ici.
//

import Cocoa
import Combine

final class EventMonitors {
    static let shared = EventMonitors()

    private var mouseMoveEvent: EventMonitor!
    private var mouseDownEvent: EventMonitor!

    let mouseLocation: CurrentValueSubject<NSPoint, Never> = .init(.zero)
    let mouseDown: PassthroughSubject<Void, Never> = .init()

    private init() {
        mouseMoveEvent = EventMonitor(mask: .mouseMoved) { [weak self] _ in
            self?.mouseLocation.send(NSEvent.mouseLocation)
        }
        mouseMoveEvent.start()

        mouseDownEvent = EventMonitor(mask: .leftMouseDown) { [weak self] _ in
            self?.mouseDown.send()
        }
        mouseDownEvent.start()
    }
}
