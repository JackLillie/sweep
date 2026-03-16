# Sweep

A free, native macOS app for system maintenance. Clean caches, manage storage, audit app permissions, and keep your Mac running smoothly.

Built on top of [Mole](https://github.com/tw93/mole). (I ❤️ Mole)

## Features

- **Overview** — real-time CPU, memory, and disk usage at a glance
- **Smart Clean** — scan and remove caches, logs, browser data, build artifacts, and trash via Mole
- **Applications** — browse and uninstall apps, sorted by size
- **Storage** — visualize disk usage, drill into directories, find large files
- **Permissions** — audit which apps have access to camera, mic, location, full disk access, etc.
- **Menu bar** — quick stats and one-click actions without opening the full app

## Requirements

- macOS 14.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the Xcode project)
- [Go](https://go.dev) (to compile Mole's binaries — bundled automatically during build)

Mole is included as a git submodule and built from source during the Xcode build process. No need to install it separately.

## Building

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

## License

MIT — see [LICENSE](LICENSE) for details.
