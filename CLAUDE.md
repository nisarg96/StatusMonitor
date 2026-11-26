# StatusMonitor — Project Guide for Claude

**Model routing:** code and implementation → Haiku; general reasoning → Sonnet; planning and hard decisions → Opus. Full rules in `~/.claude/CLAUDE.md`.

Native macOS menu bar app (Swift 6 toolchain, language mode 5, macOS 13+) that shows CPU, used RAM, and network throughput in the status bar. Configurable through a popover. No third-party packages, no Electron, no shelling out to `top`/`ps`.

## Commands

| Task | Command |
|---|---|
| Build release `.app` | `./compile.sh` |
| Build debug `.app` | `CONFIG=debug ./compile.sh` |
| Run unit tests | `swift test` |
| Headless sample dump | `build/StatusMonitor.app/Contents/MacOS/StatusMonitor --dump-samples 10` |

## Architecture (clean architecture + MVVM)

Dependencies point **inward only**. Outer layers may import inner ones, never the reverse.

```
Sources/
├── StatusMonitorCore/              # library: everything testable, no UI
│   ├── Domain/                     # pure Swift, no Foundation I/O, no Darwin
│   │   ├── Model/                  # value types: CPUTicks, InterfaceCounters, SystemSnapshot, MetricSettings
│   │   └── Services/               # pure calculators: CPUUsageCalculator, NetworkRateCalculator, InterfaceFilter
│   ├── Application/
│   │   ├── Ports/                  # protocols the outside world must implement
│   │   └── UseCases/               # SampleSystemMetricsUseCase: orchestrates ports + domain
│   ├── Presentation/               # MVVM: view models and formatting (no SwiftUI/AppKit imports)
│   │   ├── ViewModels/             # SettingsViewModel, MonitorViewModel
│   │   └── Formatting/             # Format, StatusTitleFormatter, ReadoutBuilder, InterfaceAllowListParser
│   └── Infrastructure/             # adapters implementing ports
│       ├── Darwin/                 # Mach host_statistics(64), getifaddrs, monotonic clock
│       ├── Persistence/            # UserDefaults-backed SettingsRepository
│       └── Scheduling/             # RunLoop timer-based RefreshScheduling
├── StatusMonitor/                  # executable: thin AppKit/SwiftUI shell
│   ├── App/                        # main-level wiring: AppDelegate, CompositionRoot
│   ├── UI/                         # StatusBarController (NSStatusItem), DashboardView (SwiftUI)
│   └── CLI/                        # --dump-samples diagnostic
Tests/
└── StatusMonitorCoreTests/         # mirrors Sources/StatusMonitorCore: Domain/, Application/, Presentation/, Infrastructure/, Support/
```

### Rules

1. **Domain** has no imports beyond `Foundation`. It must not know about UserDefaults, Mach, AppKit, or SwiftUI.
2. **Application** depends only on Domain and its own ports. Use cases receive adapters through their initializers.
3. **Presentation** (view models) depends on Domain + Application ports. It never imports `AppKit`/`SwiftUI`. Views observe view models; logic goes in view models or pure formatters.
4. **Infrastructure** implements ports. Only `CompositionRoot` (in the executable target) chooses concrete adapters.
5. **UI** (`StatusMonitor` target) binds to view models and renders. It has no business logic.
6. Anything the executable needs from the library is `public`. Tests use `@testable import`.
7. One type per file. File name equals type name, except for small enums grouped by concern (e.g. `Formatters.swift`).

### Where new code goes

| Adding... | Put it in |
|---|---|
| A new metric source | Port in `Application/Ports/`, adapter in `Infrastructure/Darwin/`, pure math in `Domain/Services/` |
| A new setting | `Domain/Model/MetricSettings.swift`, persistence key in `UserDefaultsSettingsRepository`, setter in `SettingsViewModel`, toggle in `DashboardView` |
| New display text / formatting | `Presentation/Formatting/` (pure, with tests) |
| New popover control | `UI/DashboardView.swift`, bound to an existing or new view model property |

## Conventions

- **TDD.** Write the failing test in `Tests/StatusMonitorCoreTests/` first, then the code. Domain and Presentation logic must be covered without touching the system. Fakes live in `Tests/StatusMonitorCoreTests/Support/Fakes.swift`.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`). Name suites after the type under test.
- Counters from the kernel are 32-bit and wrap. Always use wrapping subtraction (`&-`) for deltas.
- Rates divide by **measured** elapsed time, not the nominal interval.
- Units: `GB` means GiB (1024³), and rates use 1024 steps. Say so in comments wherever units matter.
- "GB" in the CPU mode means **used RAM**, shown as `RAM` in the bar. It is not CPU load.
- Refresh cadence: 2 s while the popover is open, 5 s while closed.
- No third-party dependencies. No `top`/`ps` shell-outs. No Accessibility or Screen Recording permissions. `getifaddrs` and `host_statistics` require none.
- Keep `compile.sh`, `Support/Info.plist`, and `Package.swift` in step. `LSUIElement` must stay `true` so the app has no Dock icon.

## Known limitations

- `if_data` counters are 32-bit. A single interface transferring more than 4 GiB between two samples (about 2 GB/s at a 2 s cadence) would wrap and under-report. The spec mandates `getifaddrs`, so 64-bit `NET_RT_IFLIST2` counters are out of scope.
- The popover and status bar are AppKit/SwiftUI and are not unit-tested. Verify them manually.

## Git

Commit only when asked. Commit messages and PR descriptions follow the attribution lines supplied in the session.
