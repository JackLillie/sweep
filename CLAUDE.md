# Sweep

A free, native macOS system maintenance app built on top of [tw93/mole](https://github.com/tw93/mole).

## Architecture

- **SwiftUI** macOS app targeting macOS 14.0+
- **Mole** is a git submodule at `mole/` — never modify its contents. Sync upstream with `git fetch upstream && git merge upstream/main`
- **Bridge layer** (`Sweep/Bridge/MoleBridge.swift`) wraps Mole's CLI and translates output into Swift types. If Mole changes its output format, fix the bridge — not the app views, not Mole
- **xcodegen** generates `Sweep.xcodeproj` from `project.yml`. Run `xcodegen generate` after changing project structure

## Project Structure

```
Sweep/
├── mole/                   # git submodule — DO NOT MODIFY
├── project.yml             # xcodegen project definition
└── Sweep/
    ├── SweepApp.swift      # app entry point + menu bar extra
    ├── Bridge/             # Mole CLI wrapper
    ├── Models/             # data types
    └── Views/              # SwiftUI views
```

## Building

```sh
xcodegen generate    # regenerate xcodeproj after structural changes
xcodebuild -project Sweep.xcodeproj -scheme Sweep -configuration Debug build
```

## Distribution

Direct distribution (notarized .dmg), not Mac App Store. No sandbox — the app needs filesystem access for system maintenance tasks.

## Conventions

- Use native macOS patterns: `NavigationSplitView`, `GroupBox`, SF Symbols, system colors
- No third-party UI dependencies — SwiftUI only
- Keep views thin — business logic goes in `AppViewModel` or the bridge
- All Mole interaction goes through `MoleBridge` — views never shell out directly
- Completely free: no ads, no subscriptions, no in-app purchases, no tracking
