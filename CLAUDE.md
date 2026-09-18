# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Le projet

Notch2000 est une app macOS (14+) qui affiche le quota de la session Claude (fenêtre de 5 heures) sous forme d'une fine barre au bord bas du notch du MacBook. Tout le code, les commentaires, les chaînes localisées et les messages de commit sont en français. Le `README.md` fait exception : il est en anglais, parce que le dépôt est public, et il se limite aux informations applicatives utiles à un fork (ce que fait l'app, d'où viennent les données, où sont les classes). Rien sur la construction ni la publication, qui relèvent du dépôt privé.

## Construire

Le `.xcodeproj` est généré par xcodegen (il est dans `.gitignore`) :

```bash
xcodegen generate
xcodebuild -project Notch2000.xcodeproj -scheme Notch2000 -configuration Release build
```

Variante sans licence Xcode acceptée (Command Line Tools seuls) :

```bash
Scripts/build.sh          # produit build/Notch2000.app
open build/Notch2000.app
```

`Scripts/build.sh` compile sans gestionnaire de paquets : Sparkle n'y est pas résolu, et `Updater.swift` est conditionné par `#if canImport(Sparkle)` pour que l'app reste complète sans lui. La version est définie deux fois : `MARKETING_VERSION` dans `project.yml` (référence pour la publication) et `VERSION` dans `Scripts/build.sh`, à garder synchronisées.

Il n'y a pas de suite de tests. Pour vérifier visuellement les états sans consommer l'API :

```bash
N2K_FAKE_PCT=88 N2K_FAKE_RESET_MIN=36 open -a Notch2000
```

Une fenêtre de développement (`Notch2000/Debug/DebugWindow.swift`) force le pourcentage et le temps restant par curseurs et relève la marge HDR. Elle est mise en commentaire pour la publication : pour la rétablir, décommenter le fichier et l'appel dans `AppDelegate`, puis lancer avec `N2K_DEBUG=1`.

## Architecture

Trois couches, reliées par Combine et SwiftUI :

**Données (`Notch2000/Usage/`)** : `Keychain.swift` lit le jeton OAuth déposé par Claude Code dans le trousseau macOS (service `Claude Code-credentials`). `ClaudeUsageService` (un actor) interroge `https://api.anthropic.com/api/oauth/usage` et met le jeton en cache jusqu'à son expiration. `UsageModel` (`@MainActor ObservableObject`) tient l'état (`syncing` / `live` / `unavailable`), pilote la boucle de rafraîchissement et publie `now` toutes les 15 s pour faire vivre le compte à rebours et le repère de temps.

**Notch (`Notch2000/Notch/`)** : couche dérivée de NotchDrop (MIT, Lakr Aream, licence dans `LICENSE-NotchDrop`). Fenêtre sans bordure ancrée en haut d'écran (`NotchWindow`), machine à trois états dans `NotchViewModel` (`closed` / `hovered` / `opened`) dont la géométrie est calculée en coordonnées écran. Le survol et les clics ne passent pas par le tracking SwiftUI : `EventMonitors` observe la souris globalement et `NotchViewModel+Events` compare la position aux rects actifs. `AppDelegate` détruit et reconstruit la fenêtre à chaque changement d'écran. `PublishedPersist` persiste les réglages en JSON dans Application Support/Notch2000.

**Vues (`Notch2000/Views/`)** : SwiftUI pur. Tous les jetons visuels (couleurs, métriques, typographie, animations, seuils) sont centralisés dans `Theme.swift` : ne pas mettre de valeur en dur dans les vues. `Settings.swift` est le singleton des réglages utilisateur.

## Contraintes à connaître avant de modifier

- **Trousseau** : l'élément appartient à Claude Code, donc chaque lecture peut déclencher le dialogue d'autorisation macOS. `ClaudeUsageService` ne relit le trousseau qu'à l'expiration du jeton ou sur un 401. Ne pas ajouter de lecture par rafraîchissement.
- **Signature** : le build local signe avec l'identité Developer ID (voir `project.yml` et `build.sh`). Une signature ad hoc change d'empreinte à chaque compilation et fait redemander l'accès au trousseau. Le runtime durci est requis par la notarisation.
- **API d'utilisation** : l'en-tête `User-Agent` est obligatoire, sans lui l'API répond 429 systématiquement. En cas de 429, respecter un plancher de 180 s avant nouvelle tentative.
- **Jeton long terme** : un `CLAUDE_CODE_OAUTH_TOKEN` ne fonctionne pas, il n'a pas la portée `user:profile` requise par l'API d'utilisation. Le trousseau est la seule source.
- **HDR et notification d'écran** : macOS envoie `didChangeScreenParametersNotification` quand la marge HDR varie, ce que provoque `HighDynamicRange`. `AppDelegate` ne reconstruit donc la fenêtre que si la géométrie des écrans a changé ; reconstruire à chaque notification recrée la fenêtre en boucle (gels, notch dessiné à gauche).
- **Localisation** : les chaînes utilisateur passent par `String(localized:)` avec des `Localizable.strings` dans `Resources/{fr,en,de,es}.lproj`. Toute nouvelle chaîne doit être ajoutée aux quatre.

## Publication

La chaîne de publication (signature, notarisation, DMG, appcast Sparkle, hébergement Scaleway) vit dans un dépôt privé séparé qui porte les secrets : [devidb/notch-2000-release](https://github.com/devidb/notch-2000-release). Ce dépôt-ci ne contient que le code ; la release publiée correspond au `MARKETING_VERSION` de `project.yml`.

## notch2000-site/

Maquette autonome du site vitrine : `index.html` (un seul fichier HTML/CSS/JS sans dépendance) et `SPEC.md` qui en décrit les mesures. Indépendante de l'app ; la vitrine réelle vit dans son propre dépôt privé, [devidb/dacodeapp-vitrine](https://github.com/devidb/dacodeapp-vitrine).
