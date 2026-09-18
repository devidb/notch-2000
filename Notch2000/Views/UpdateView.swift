//
//  UpdateView.swift
//  Notch2000
//
//  La mise à jour, racontée dans le notch plutôt que dans une fenêtre Sparkle.
//
//  C'est un bandeau, pas un écran : le notch se déplie de sa hauteur et les
//  réglages restent visibles au dessus. Une ligne de titre avec la progression
//  à sa droite, une phrase, et les boutons alignés à droite.
//

import SwiftUI

struct UpdateView: View {
    var stage: UpdateStage
    var updater: Updater

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Centré et non calé sur la ligne de base : la barre de progression
            // est un trait de 3 points, elle n'a pas de ligne de base à offrir.
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(Theme.racing(9))
                    .tracking(1.4)
                    .foregroundStyle(Theme.clay)
                    .lineLimit(1)
                    .fixedSize()

                Spacer(minLength: 8)

                meterView
                    .frame(width: 110)
            }

            Text(message)
                .font(Theme.panelHint)
                .foregroundStyle(Theme.ivory(0.62))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)

            Spacer(minLength: 6)

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                ForEach(actions, id: \.title) { action in
                    Button(action: action.run) {
                        Text(action.title)
                            .font(Theme.panelAction)
                            .tracking(0.6)
                    }
                    .buttonStyle(ChunkyButtonStyle(tone: action.isPrimary ? .clay : .neutral))
                }
            }
        }
        .padding(.top, 13)
        // Même filet que celui qui sépare les groupes de réglages.
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.ivory(0.1)).frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Theme.updateBandHeight)
    }

    // MARK: - Progression

    /// Ce que la barre de progression doit dire, s'il y a lieu.
    private enum Meter {
        case absent
        /// Durée inconnue : on montre que ça travaille, sans chiffrer l'avancement.
        case indeterminate
        case value(Double)
    }

    private var meter: Meter {
        switch stage {
        case .checking, .installing: .indeterminate
        case let .downloading(fraction): fraction.map(Meter.value) ?? .indeterminate
        case let .preparing(fraction): .value(fraction)
        default: .absent
        }
    }

    @ViewBuilder
    private var meterView: some View {
        switch meter {
        case .absent:
            EmptyView()
        case .indeterminate:
            progress(nil)
        case let .value(fraction):
            progress(fraction)
        }
    }

    /// Barre de progression reprise de la barre de session : même trait fin,
    /// même lueur, pour que le panneau ne parle qu'une langue.
    private func progress(_ fraction: Double?) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ivory(0.1))
                if let fraction {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.clay, Theme.clayVivid],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * fraction)
                        .shadow(color: Theme.clayVivid.opacity(0.7), radius: 4, y: 1)
                        .animation(Theme.fillAnimation, value: fraction)
                } else {
                    IndeterminateSweep(width: proxy.size.width)
                }
            }
        }
        .frame(height: 3)
    }

    // MARK: - Textes

    private var title: String {
        switch stage {
        case .idle: ""
        case .checking: String(localized: "RECHERCHE")
        case .found: String(localized: "MISE À JOUR")
        case .downloading: String(localized: "TÉLÉCHARGEMENT")
        case .preparing: String(localized: "PRÉPARATION")
        case .readyToRelaunch: String(localized: "PRÊT")
        case .installing: String(localized: "INSTALLATION")
        case .upToDate: String(localized: "À JOUR")
        case .failed: String(localized: "ÉCHEC")
        }
    }

    private var message: String {
        switch stage {
        case .idle:
            ""
        case .checking:
            String(localized: "Interrogation du serveur de mises à jour…")
        case let .found(version):
            String(localized: "La version \(version) est disponible. Vous utilisez la \(appShortVersion).")
        case .downloading:
            String(localized: "Récupération de la nouvelle version.")
        case .preparing:
            String(localized: "Décompression et vérification de la signature.")
        case let .readyToRelaunch(version):
            version.isEmpty
                ? String(localized: "La mise à jour est prête. Notch2000 va redémarrer.")
                : String(localized: "La version \(version) est prête. Notch2000 va redémarrer.")
        case .installing:
            String(localized: "Installation en cours, ne quittez pas l'application.")
        case .upToDate:
            String(localized: "Notch2000 \(appShortVersion) est la dernière version.")
        case let .failed(reason):
            reason
        }
    }

    // MARK: - Actions

    private struct Action {
        var title: String
        var isPrimary: Bool
        var run: () -> Void
    }

    private var actions: [Action] {
        switch stage {
        case .idle:
            []
        case .checking, .downloading:
            [Action(title: String(localized: "ANNULER"), isPrimary: false, run: updater.dismiss)]
        case .found:
            [
                Action(title: String(localized: "INSTALLER"), isPrimary: true, run: updater.install),
                Action(title: String(localized: "PLUS TARD"), isPrimary: false, run: updater.later),
            ]
        case .readyToRelaunch:
            [
                Action(title: String(localized: "REDÉMARRER"), isPrimary: true, run: updater.install),
                Action(title: String(localized: "PLUS TARD"), isPrimary: false, run: updater.later),
            ]
        case .preparing, .installing:
            []
        case .upToDate, .failed:
            [Action(title: String(localized: "FERMER"), isPrimary: false, run: updater.dismiss)]
        }
    }
}

/// Balayage sans fin, pour les étapes dont on ne connaît pas la durée.
private struct IndeterminateSweep: View {
    var width: CGFloat

    @State private var atEnd = false

    private let sweep: CGFloat = 48

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Theme.scanner.opacity(0), Theme.scanner, Theme.scanner.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: sweep)
            .offset(x: atEnd ? max(width - sweep, 0) : 0)
            .animation(Theme.scanAnimation, value: atEnd)
            .onAppear { atEnd = true }
    }
}
