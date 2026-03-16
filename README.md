<div align="center">
  <img src="Sweep/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" height="128" style="border-radius: 22px;" alt="Sweep">
  <h1>Sweep</h1>
  <p><em>A free, native macOS app for system maintenance.</em></p>
  <p>Clean caches, manage storage, audit app permissions, and keep your Mac running smoothly.</p>
  <p>Built on top of <a href="https://github.com/tw93/mole">Mole</a> (I ❤️ Mole)</p>
  <p>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
    <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg?style=flat-square" alt="Platform">
    <img src="https://img.shields.io/badge/swift-5.10-orange.svg?style=flat-square" alt="Swift">
  </p>
</div>

---

## Features

- **Overview** - real-time CPU, memory, disk, network, and battery at a glance with a health score
- **Smart Clean** - deep scan via Mole to find and remove caches, logs, browser data, dev artifacts, and more
- **Applications** - browse all installed apps with real icons, sort by size, uninstall with one click
- **Storage** - analyze disk usage category by category, drill into directories, find large files
- **Permissions** - audit which apps have access to camera, mic, location, full disk access, and 20+ other permissions
- **Menu Bar** - quick system stats and one-click actions without opening the full app
- **Tools Menu** - Empty Trash, Free Memory, Flush DNS with keyboard shortcuts

## Building

Mole is included as a git submodule and compiled automatically during the Xcode build. You need [Go](https://go.dev) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed.

```sh
git clone --recursive https://github.com/jacklillie/sweep.git
cd sweep
xcodegen generate
open Sweep.xcodeproj
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project Sweep.xcodeproj -scheme Sweep -configuration Debug build
```

## How It Works

Sweep wraps [Mole](https://github.com/tw93/mole)'s powerful CLI in a native SwiftUI interface. Mole handles the heavy lifting - scanning caches, analyzing disk usage, monitoring system health - while Sweep provides a clean, Mac-native UI on top.

The app requires **Full Disk Access** for Smart Clean, Storage analysis, and Permissions auditing. Overview and Applications work without it.

## License

MIT - see [LICENSE](LICENSE) for details.
