# StatusMonitor

A native macOS menu bar app that shows CPU load, used RAM, and network throughput in the status bar. Pick which metrics appear and how they are formatted from a popover. Pure Swift with AppKit and SwiftUI. No third-party packages.

```
CPU 8%  ↓ 2.1 MB/s  ↑ 0.4 MB/s
```

## Requirements

- macOS 13 or later
- Swift 5.9+ toolchain (Xcode or Command Line Tools)

## Build and run

```sh
./compile.sh                       # release build → build/StatusMonitor.app
open build/StatusMonitor.app       # launches into the menu bar
```

Debug build: `CONFIG=debug ./compile.sh`

To quit, open the popover and press **Quit** (⌘Q).

## Configuration

Click the menu bar item to open the popover:

| Setting | Effect |
|---|---|
| CPU → Show in menu bar | Shows or hides the CPU/RAM segment |
| CPU → Display | `Percent` (`CPU 12%`) or `Used RAM (GB)` (`RAM 3.2 GB`) |
| Network → Show in menu bar | Shows or hides the ↓/↑ segment |
| Network → Include loopback | Counts `lo0` traffic (off by default) |
| Network → Interfaces | Comma-separated names such as `en0, utun3`. Blank counts all active interfaces |

Settings are saved to UserDefaults (`defaults read` with your bundle identifier) and restored on launch. No restart is needed.

## Testing

```sh
swift test
```

The unit tests cover the domain calculators, use case, formatters, view models, and the settings repository. They do not touch the live system. Architecture and conventions are in [CLAUDE.md](CLAUDE.md).

## Diagnostics

Print the same status text the menu bar shows, once every 2 seconds, without the GUI:

```sh
build/StatusMonitor.app/Contents/MacOS/StatusMonitor --dump-samples 10
```

## Permissions

None. Metrics come from `host_statistics(64)` and `getifaddrs` (AF_LINK), and the app requests no TCC permissions.

## Project layout

```
StatusMonitorCore/   library: Domain, Application, Presentation (view models), Infrastructure
StatusMonitor/       executable: AppDelegate, CompositionRoot, StatusBarController, DashboardView
StatusMonitorCoreTests/
Support/Info.plist   bundle metadata (LSUIElement = true, no Dock icon)
compile.sh           build + bundle + ad-hoc codesign
```
