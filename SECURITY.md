# Security

Notch2000 reads the OAuth token that Claude Code stores on your machine. That
puts it in a sensitive position, so reports are welcome and taken seriously.

## Reporting a vulnerability

Please **do not open a public issue** for anything that could be abused before a
fix ships. Use GitHub's private vulnerability reporting instead: go to the
[Security tab](https://github.com/devidb/notch-2000/security) and choose *Report
a vulnerability*. That opens a private thread visible only to the maintainer.

Public issues remain the right place for ordinary bugs.

## Scope

Anything that could expose or misuse the Claude Code credentials is in scope,
as is anything that could let a third party push code to an installed copy.
Concretely:

- credential handling in `Notch2000/Usage/ClaudeCredentials.swift`,
- the single network call in `Notch2000/Usage/ClaudeUsageService.swift`,
- the update path (feed, signature verification, installation).

The app runs outside the sandbox under the hardened runtime, and is signed and
notarised. It holds no server side component, so there is no backend to test.

## What the app does with your credentials

It reads the token, sends it to `https://api.anthropic.com/api/oauth/usage`, and
keeps it in memory until it expires. It stores no copy, opens no session of its
own, and never writes to Claude Code's keychain item. The only other host it
contacts is the update feed declared in `Info.plist`, which carries no
credentials.

## Updates

Releases are delivered through Sparkle. Each build is signed with an EdDSA key
whose public half is embedded in the app (`SUPublicEDKey` in `Info.plist`), and
Sparkle refuses any update it cannot verify against it. A compromised download
host is therefore not enough to push code onto your machine.

## Supported versions

Only the latest release is supported. The app updates itself by default, so
please reproduce on the current version before reporting.
