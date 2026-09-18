# Notch2000

A single lit line, and nothing else.

Notch2000 is a macOS app that shows how much of your current Claude session quota
(the rolling 5 hour window) has been used, as a thin bar along the bottom edge of
your MacBook notch. On hover, the notch drops a few points below the camera to reveal
the percentage used, riding at the tip of the fill, and the renewal time, above the
time marker. At the limit, the line stays full and still: there is
nothing to do, so nothing moves.

Requires macOS 14 or later. On a Mac without a notch, the app falls back to a
centred template at the top of the built-in display.

This README documents the app itself, for users and for anyone forking the code.
Packaging, signing, notarisation and update hosting live in a separate private
repository and are deliberately out of scope here.

## What you see

| State | Appearance |
| --- | --- |
| Idle | The bar alone, filled in proportion to the session consumed |
| Hover | The notch drops below the camera, percentage and renewal time appear on the bar |
| Limit (100 %) | The bar is full and still |
| Syncing | The bar empties, a dot sweeps across it, Knight Rider style |

Clicking the notch opens a quick settings panel; clicking anywhere else closes it.

### The time marker

Disabled by default. When enabled, a thin white needle rises from the bar at the position of the
elapsed time within the 5 hour window, with a small gap cut into the fill on each side
so it stays readable over a bright fill. If it falls inside the amber zone, you are burning
quota faster than time is passing. In the code it still carries its original name,
the KITT dot.

### Settings

All settings live in `Settings.swift` and are persisted as JSON in
`~/Library/Application Support/Notch2000/Config`:

| Key | Meaning | Values | Default |
| --- | --- | --- | --- |
| `barStyle` | How the gauge is drawn | `line`, `dots` | `line` |
| `barPalette` | Gauge colour | `claude` (Claude orange throughout), `consumption` (mint, amber, ember by level) | `claude` |
| `glowIntensity` | Halo around the bar | `soft`, `strong` | `strong` |
| `hdrEnabled` | Push the bar, the marker and the figures beyond SDR white on HDR displays | `true`, `false` | `true` |
| `kittEnabled` | Show the elapsed time marker on the bar | `true`, `false` | `false` |
| `digitsAlwaysVisible` | Keep the figures visible instead of showing them on hover only | `true`, `false` | `false` |
| `renewalDisplay` | Renewal value: time of day or countdown | `target`, `countdown` | `target` |

The quota is read once a minute; the countdown and the time marker are recomputed
locally in between.

Launch at login is not persisted here: it reflects the real state of
`SMAppService.mainApp`.

## Where the data comes from

Notch2000 reads the OAuth token that Claude Code stores, then queries Anthropic's
usage API. Claude Code must therefore be installed and signed in on the machine.

Claude Code has two possible stores, and Notch2000 reads both: the macOS keychain
(service `Claude Code-credentials`), its default, and `~/.claude/.credentials.json`,
the fallback it uses when the keychain is unavailable (remote session, terminal
without access to the security agent, `claude setup-token`). Reading only the
keychain would make a perfectly signed in machine look signed out. On first launch,
macOS asks for permission to access the keychain item.

Notch2000 stores no credentials, opens no session of its own, and never modifies
Claude Code's tokens.

An app that reaches into your keychain to read a token looks exactly like a
credential stealer, and the macOS dialog gives you no way to tell the difference.
That is why this code is open. Two files are enough to check:
`Notch2000/Usage/ClaudeCredentials.swift` reads the credentials, and
`Notch2000/Usage/ClaudeUsageService.swift` sends it to a single address,
`https://api.anthropic.com/api/oauth/usage`. The app contacts exactly one other
host, the Sparkle update feed declared in `Info.plist`, which carries no
credentials.

Three constraints that any fork will run into:

- **Keychain.** The item belongs to Claude Code, so every read can raise the macOS
  authorisation dialog. `ClaudeUsageService` re-reads the keychain only when the
  token expires or on a 401. Do not add a read per refresh.
- **Code signing.** An ad hoc signature changes its fingerprint on every build,
  which makes macOS ask for keychain access again every time. A stable signing
  identity avoids that.
- **Usage API.** The `User-Agent` header is mandatory; without it the API answers
  429 every time. On a 429, honour a floor of 180 s before retrying. A long lived
  `CLAUDE_CODE_OAUTH_TOKEN` does not work either, it lacks the `user:profile`
  scope the usage API requires. Claude Code's own credentials are the only source.

## Previewing states

To walk through the visual states without calling the API:

```bash
N2K_FAKE_PCT=88 N2K_FAKE_RESET_MIN=36 open -a Notch2000
```

`N2K_FAKE_PCT` forces the percentage (0 to 100) and `N2K_FAKE_RESET_MIN` the number
of minutes before renewal.

## Code map

Three layers, wired together with Combine and SwiftUI.

**Data, `Notch2000/Usage/`**

| File | Role |
| --- | --- |
| `ClaudeCredentials.swift` | Reads the Claude Code OAuth token, from the macOS keychain or from `~/.claude/.credentials.json`, and reports which of the two it used |
| `ClaudeUsageService.swift` | `actor` that queries the usage API, caches the token until expiry, maps errors (`UsageError`) and returns a `UsageSnapshot` |
| `UsageModel.swift` | `@MainActor ObservableObject` holding the state (`syncing` / `live` / `unavailable`), driving the refresh loop and republishing `now` every 15 s to keep the countdown and the time marker alive |

**Notch, `Notch2000/Notch/`**, derived from NotchDrop (see Credits)

| File | Role |
| --- | --- |
| `NotchWindow.swift`, `NotchWindowController.swift`, `NotchViewController.swift` | Borderless window anchored at the top of the screen, hosting the SwiftUI tree |
| `NotchViewModel.swift` | Three state machine (`closed` / `hovered` / `opened`), geometry computed in screen coordinates |
| `NotchViewModel+Events.swift`, `EventMonitors.swift`, `EventMonitor.swift` | Hover and clicks do not go through SwiftUI tracking: the mouse is watched globally and its position compared with the active rects |
| `Ext+NSScreen.swift` | Notch detection and screen metrics |
| `HighDynamicRange.swift` | Requests the high dynamic range on the notch window layers, so HDR colours hold while the app is in the background |
| `PublishedPersist.swift` | Property wrappers persisting settings as JSON in Application Support |

**Views, `Notch2000/Views/`**, pure SwiftUI

| File | Role |
| --- | --- |
| `NotchRootView.swift` | Root view, assembles the shape, the bar and the panel |
| `NotchShape.swift` | The notch outline |
| `SessionBar.swift` | The bar itself: fill, glow, time marker, sync sweep |
| `SessionDots.swift` | The same gauge drawn as a row of squares |
| `QuickPanelView.swift` | Quick settings panel |
| `Chunky.swift` | The raised controls of the panel: a lit face sitting on a dark edge, pressing sinks the face onto its edge |

**Top level**

| File | Role |
| --- | --- |
| `main.swift` | Entry point, single instance guard, Application Support directory |
| `AppDelegate.swift` | Destroys and rebuilds the window when the screen geometry changes |
| `Theme.swift` | Every visual token (colours, metrics, typography, animations, thresholds). Views must not hardcode values |
| `Settings.swift` | User settings singleton |
| `Updater.swift` | Sparkle integration with its standard windows, guarded by `#if canImport(Sparkle)` so the app stays complete without it |
| `Debug/DebugWindow.swift` | Development window (forced percentage and remaining time, HDR headroom readout), commented out in releases |

The Xcode project is not checked in: it is generated from `project.yml` by
[xcodegen](https://github.com/yonaskolb/XcodeGen).

## Localisation

User facing strings go through `String(localized:)`, with `Localizable.strings` in
`Notch2000/Resources/{fr,en,de,es}.lproj`. Any new string must be added to all
four. The source language is French, so the keys are the French strings.

## Credits

Notch handling (borderless window anchored at the top of the screen, global pointer
tracking, rebuild on screen change, settings persistence) is derived from
[NotchDrop](https://github.com/Lakr233/NotchDrop) by Lakr Aream, distributed under
the MIT licence. That licence text is kept in `LICENSE-NotchDrop`.

The app ships the [Michroma](https://github.com/googlefonts/Michroma-font) typeface,
under the SIL Open Font License 1.1, kept in `LICENSE-Michroma`.

## Licence

[PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0),
see `LICENSE`. Fork it, change it, share it, run it: anything noncommercial is
allowed, including hobby projects, study, research, and use by nonprofit or public
organisations. Selling this app or a derivative of it, or building a commercial
offering on top of it, is not. For a commercial licence, open an issue.

Note that this is a source available licence, not an OSI approved open source one.
The code up to the `v0.1.0` tag was published under the MIT licence and stays
available under those terms.

The NotchDrop portions keep their own MIT licence, kept in `LICENSE-NotchDrop`,
whose notice must accompany any distribution. The app bundle ships it.
