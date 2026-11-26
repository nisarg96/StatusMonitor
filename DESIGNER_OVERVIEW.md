# StatusMonitor — Project Overview for Design

## What it is

StatusMonitor is a native macOS menu bar app. It shows live system metrics in the menu bar, and it can take a small set of automatic actions when a metric crosses a limit the user chose.

- **Platform:** macOS 13 and later. Apple Silicon and Intel.
- **Stack:** Swift, SwiftUI for the windows and popover, AppKit for the menu bar items. No third-party libraries.
- **Shape:** no Dock icon. Everything lives in the menu bar, plus one Settings window.
- **Status:** working prototype. Monitoring works. Some controls are still in progress. The design work is what this brief is for.

## What the user sees

### 1. The menu bar

Each metric is its own item in the menu bar, and the user can show, hide, or reorder them. The menu bar is crowded, so every item must be as narrow as possible.

Metrics available as items:

| Item | Shows | Notes |
|---|---|---|
| CPU | Overall load, %. Per-core bars are not available yet. | |
| RAM | Used memory, GB, or % | |
| GPU | Utilisation, % | Not on every Mac |
| Memory pressure | Normal, Warning, or Critical | Kernel-reported |
| Network | Upload and download speed | |
| Disk | Read and write speed | |
| Battery | Charge %, charging state | Laptops only |
| Temperature | CPU °C | Not on every Mac |

Items that the Mac cannot provide are never shown. Items with no value yet show their icon alone, never "N/A" or "0".

Each item has a priority: High, Medium, or Low. The plan is that when the menu bar runs out of room, Low items hide first, then Medium. macOS gives apps no public way to measure free menu bar width, so the app detects overflow from where its items end up on screen.

### 2. The popover (click an item)

The popover shows live readouts for the metrics, grouped by section: CPU and memory, GPU, memory pressure, disk, battery, network, and thermal. Each section has its own toggles.

Battery has its own detail toggles: charge, health, cycle count, power source, Low Power Mode, and time remaining.

Below the sections are the Memory Clean controls and the General settings.

### 3. The Settings window (planned, being designed)

A separate window holding all configuration, so the popover stays short. Planned sections:

- **Menu bar items:** a reorderable list. Each row has an on/off switch and a priority. The detail panel for each item covers: metrics shown, display style, refresh rate, hide-when-idle with a threshold, alert colour and threshold, and what a click does.
- **General:** open at login, and the purge permission for Memory Clean.
- **Memory Clean:** Auto Clean on/off, and a stepped slider from 70% to 100% of RAM in use. The label shows the equivalent free memory in GB.
- Later: sampling, alerts, and about.

### 4. Memory Clean

Memory Clean frees inactive memory by running macOS's `purge` command. It needs a one-time administrator approval.

- **Standard clean:** one purge.
- **Extreme clean:** purge, then a memory-pressure step, then a second purge. Each step is measured.
- **Auto Clean:** runs a standard clean when used RAM reaches the threshold. It waits at least 3 minutes between cleans.
- Every clean is logged, with the memory freed.

Design should make clear that this frees inactive file cache only. It does not free memory held by running apps.

### 5. Weather (planned)

A later module: current conditions in the menu bar and a Weather section. Location is requested only when the user turns the feature on.

## Display styles (for the status bar)

Each item can be drawn in one of these styles. The menu bar is about 22 pt high, so everything must read at small size:

- **Value:** icon and one value, e.g. CPU 14%.
- **Stacked:** two values in one slot, e.g. upload above download.
- **Bars:** small vertical bars for recent samples.
- **Sparkline:** a line through recent samples, plus the current value.
- **Ring:** a circle filled to the percentage.
- **Grouped with alert:** two related values; the item turns orange when a threshold is crossed.

Alerts use orange for warning and red for critical. The design should not rely on colour alone, so each alert also needs a shape or weight change.

## Constraints the design must respect

- **Width:** the menu bar is shared with the system and other apps. Each item should be as narrow as it can while staying readable.
- **Icons:** SF Symbols only, so they match the system's menu bar. No emoji in the bar.
- **Dark and light menu bars:** the menu bar changes with the wallpaper. Items must work on both.
- **Stable width:** values change constantly, so use fixed-width digits, or the items jitter.
- **Accessibility:** colour must not be the only signal, and touch targets and text should meet macOS norms.
- **Permissions:** the app asks for no Screen Recording or Accessibility access. The one privileged action (purge) is installed by the user, once, with an administrator password.
- **Signing:** the app is not yet code-signed for distribution, so some system features are unavailable until it is.

## Existing visual direction

A design mockup already exists for the status bar styles, the Settings window, the popover network card, and an app icon called "Meterbar". It is in the project's design canvas, and the link is shared separately. Treat it as a starting point, not a final answer.

Current accent colour in the code is a green-teal (#2BD4A4 on dark). Alerts are orange and red.

## Open questions for the designer

1. **Status bar:** which display style should be the default for each item, given the width limit?
2. **Settings window:** should the item list and the detail panel sit side by side, or should the detail open as a sheet?
3. **Popover:** how should the network card show upload and download, history, and daily totals, while staying compact?
4. **Alerts:** what is the clearest non-colour signal for a warning and for a critical state?
5. **Empty and unavailable states:** how should an item look when the Mac cannot provide its metric? (Design rule: it is hidden, not shown as N/A.)
6. **App icon:** the "Meterbar" concept, with a dark and a light version, sized for 16 to 1024 pt.
7. **Naming:** do the menu bar labels (CPU, RAM, Mem, GPU) need to change for clarity?

## What is not decided yet

- Whether per-core CPU bars are possible. The app currently reads overall CPU only.
- How aggressive automatic hiding should be when the menu bar is full.
- Final names for the Memory Clean actions.
