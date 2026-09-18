//
//  main.swift
//  Notch2000
//
//  Point d'entrée. La garde d'instance unique est reprise de NotchDrop (MIT, Lakr Aream).
//

import AppKit

let bundleIdentifier = Bundle.main.bundleIdentifier ?? "app.notch2000"

let appVersion: String = {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "0.0"
    let build = info?["CFBundleVersion"] as? String ?? "0"
    return "\(short) (\(build))"
}()

/// Dossier de configuration, utilisé par `PublishedPersist`.
let documentsDirectory: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let directory = base.appendingPathComponent("Notch2000")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}()

let pidFile = documentsDirectory.appendingPathComponent("ProcessIdentifier")

// Une seule instance à la fois : la précédente est priée de se retirer.
if let previous = try? String(contentsOf: pidFile, encoding: .utf8),
   let pid = Int(previous.trimmingCharacters(in: .whitespacesAndNewlines)),
   pid != Int(NSRunningApplication.current.processIdentifier),
   let app = NSRunningApplication(processIdentifier: pid_t(pid))
{
    app.terminate()
}
try? String(NSRunningApplication.current.processIdentifier)
    .write(to: pidFile, atomically: true, encoding: .utf8)

// Le code de premier niveau s'exécute sur le fil principal avant toute concurrence.
private let delegate = MainActor.assumeIsolated { AppDelegate() }
MainActor.assumeIsolated { NSApplication.shared.delegate = delegate }
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
