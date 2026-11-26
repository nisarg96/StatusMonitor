# StatusMonitor — Project Overview for Design

## What it is

StatusMonitor is a native macOS menu bar app. It shows live system metrics in the menu bar and in a popover, and it can run one memory action, Memory Clean, either by hand or when used RAM reaches a threshold the user sets.

- **Platform:** macOS 13 and later. Apple Silicon and Intel. Only Apple Silicon has been tested.
- **Stack:** Swift, SwiftUI for the popover and Settings window, AppKit for the menu bar items. No third-party libraries.
- **Shape:** no Dock icon. Everything lives in the menu bar, the popover that opens from it, and one Settings window.
- **Status:** working prototype. Monitoring works. Memory Clean is built, but its install path and a real clean have not been run on a real Mac (see `LIMITATIONS.md`). Some design questions are open (see the end of this document).

## What the user sees

### 1. The menu bar

Each metric is its own item, and the user can show, hide, or reorder them. RAM has no item of its own: the CPU item can show used RAM in GB instead of CPU load. The menu bar is crowded, so every item must be as narrow as possible.

| Item | Shows | Notes |
|---|---|---|
| CPU | Overall CPU load, %, or used RAM in GB (labelled RAM) | Per-core bars are not available. The choice is made in Settings. |
| GPU | Utilisation, % | Only on Macs that report GPU load |
| Memory pressure | Normal, Warning, or Critical, as an icon | Kernel-reported. Hidden in the bar by default |
| Network | Upload and download speed | |
| Disk I/O | Read and write speed | Hidden in the bar by default. Hides while idle by default |
| Battery | Charge, %, in the bar | Laptops only. Hidden in the bar by default |
| Temperature | CPU °C | Not on every Mac. Hidden in the bar by default |

Items that the Mac cannot provide are never shown. Items with no value yet show their icon alone, never "N/A" or "0".

Each item has a priority, High, Medium, or Low, which the user can set in Settings. **Priority does not hide anything yet.** The intended behaviour is that when the menu bar runs out of room, Low items hide first, then Medium. That is not built. macOS gives apps no public way to measure free menu bar width, so the app would have to detect overflow from where its items end up on screen. The footnote in Settings describes the intended behaviour, and the app does not do it yet.

### 2. The popover (click an item)

The popover is a column of cards, in this order: CPU and memory, GPU, memory pressure, disk, battery, temperature, network, Memory Clean, and Open at login. Most cards have a checkbox that shows or hides them. A card for a metric the Mac cannot provide is not shown.

- **CPU and memory:** CPU load and used RAM, with a history chart.
- **Battery:** charge, with a bar, and the other readings. Each reading can be turned off in Settings (see General below).
- **Network:** upload and download speed, a sparkline, and today's totals. The sparkline and history charts show the value and time under the pointer.
- **Memory Clean:** a Standard clean button, an Extreme clean button, an Auto Clean switch with its threshold, the result of the last clean, and the line "Frees inactive file cache only. Memory used by open apps stays as it is."
- **Open at login:** a switch.

The footer has **Settings…** and **Quit StatusMonitor**. A gear icon in the header also opens Settings.

### 3. The Settings window

A separate window holds all configuration, so the popover stays short. The window has a sidebar.

- **Menu bar items:** a list on the left, and the selected item's detail on the right. Each row has a drag handle, the item's name with its style, a priority picker, and a Show switch. The list order is the order in the bar. The detail for the selected item has:
  - light and dark previews of the item in the menu bar;
  - a **Shows** choice, which applies to CPU only (CPU % or RAM GB);
  - a **Style** row of chips, limited to the styles that suit the item;
  - **Hide while idle** with an idle threshold, for network and disk I/O;
  - **Warning** with one threshold, which turns the item into its warning state;
  - **On click**: show the popover, open Activity Monitor, or nothing;
  - **Show card in the popover**, for metrics that have a card;
  - a history chart with summary figures.
- **General:** Theme (System, Light, or Dark), Open at login, Battery details (eight switches: charge row, watts, battery % in the menu bar, health, cycle count, power state, Low Power Mode, time remaining), and Network (include loopback, and a list of interfaces to count, blank for all).
- **Memory Clean:** a note on what purge does, the administrator approval (an "Installed" pill with **Remove**, or **Install…**), the Auto Clean switch, a threshold slider from 70% to 100% in 5% steps with a line giving the free memory in GB, the Standard clean and Extreme clean cards with **Clean now** buttons, and a list of recent cleans with their time, type, and memory freed.
- **Coming later** (greyed out, not selectable): Sampling, Alerts, About.

### 4. Memory Clean

Memory Clean frees inactive file cache by running macOS's `purge` command. It needs a one-time administrator approval, given in Settings > Memory Clean.

- **Standard clean:** one purge.
- **Extreme clean:** purge, then `memory_pressure -l warn`, then a second purge. Each step is measured.
- **Auto Clean:** runs a Standard clean when used RAM reaches the threshold. Today it waits at least 3 minutes between cleans. A change in progress adds a sustain period, a longer wait after cleans that free little, and a pause after repeated failures. See `MEMORY_CLEAN.md`.
- Every clean is written to a log file, with the memory it freed.

The design must make clear that this frees inactive file cache only. It does not free memory held by running apps. The Auto Clean trigger uses used RAM, which does not count file cache, so a clean will often leave the used RAM figure about where it was.

## Display styles (for the status bar)

Each item can be drawn in one of these styles. The menu bar is about 22 pt high, so everything must read at small size:

- **Value:** icon and one value, e.g. CPU 14%.
- **Stacked:** two values in one slot, e.g. upload above download.
- **Bars:** small vertical bars for recent samples.
- **Sparkline:** a line through recent samples, plus the current value.
- **Ring:** a circle filled to the percentage.
- **Grouped:** two related values in one item.
- **Icon only:** used for memory pressure, where the icon's shape carries the state.

Which styles each item offers is set in the code. Stacked is the default for network and disk I/O, and icon only is the default for memory pressure.

Alerts: a warning shows an orange item, a triangle before the value, and bold digits. A critical state fills the item in red and adds a leading "!". The design must not rely on colour alone, and the current pair of shapes is one answer to that. The Settings threshold sets only the warning level.

## Constraints the design must respect

- **Width:** the menu bar is shared with the system and other apps. Each item should be as narrow as it can while staying readable.
- **Icons:** SF Symbols only, so they match the system's menu bar. No emoji in the bar.
- **Dark and light menu bars:** the menu bar changes with the wallpaper. Items must work on both.
- **Stable width:** values change constantly, so use fixed-width digits, or the items jitter.
- **Accessibility:** colour must not be the only signal, and touch targets and text should meet macOS norms.
- **Permissions:** the app asks for no Screen Recording or Accessibility access. The one privileged action, purge, is approved by the user once, with an administrator password, from Settings > Memory Clean.
- **Signing:** the app is ad-hoc signed for local use. It is not signed with a Developer ID, which the signed-helper options require.

## Existing visual direction

A design mockup already exists for the status bar styles, the Settings window, the popover network card, and an app icon called "Meterbar". It is in the project's design canvas, and the link is shared separately. Treat it as a starting point, not a final answer.

The accent colour in the code is green-teal: `#0F7A5F` in light mode and `#2BD4A4` in dark mode. The icon uses the same teal. Alerts are orange (warning) and red (critical).

## Open questions for the designer

1. **Status bar:** which display style should be the default for each item, given the width limit? The current defaults are listed in `CONFIGURATION.md`.
2. **Settings window:** the list and the detail are side by side in the current build. Should the detail open as a sheet instead?
3. **Popover:** how should the network card show upload and download, history, and daily totals, while staying compact? The current card shows all three.
4. **Alerts:** is the current pair (orange with a triangle and bold digits for warning; filled red with "!" for critical) clear enough without colour?
5. **Empty and unavailable states:** how should an item look before its first value? The current rule is an icon alone. Unavailable metrics are hidden.
6. **App icon:** the "Meterbar" concept, with a dark and a light version, sized for 16 to 1024 pt. The current icon files are in `Support/`.
7. **Naming:** do the menu bar labels (CPU, RAM, GPU) need to change for clarity? RAM appears only as the CPU item's "RAM GB" value.

## What is not decided yet

- Whether per-core CPU bars are possible. The app reads overall CPU only.
- How the menu bar should hide items when it is full. The priority settings exist, but hiding is not built.
- Final names for the Memory Clean actions. The current labels are "Standard clean", "Extreme clean", and "Clean now".
