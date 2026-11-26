# Design spec: StatusMonitor

Source: the design canvas "Mac menu bar metrics app". Artboards: Main (menu bar styles), Popover, Settings (menu bar items), Settings · Memory Clean, States (alerts, empty, overflow), App icon. The app should match these artboards. Where the app cannot yet provide a value, the item is hidden, never shown as "N/A" or "0".

Rules for applying this spec:
- Every colour is a light/dark pair. The light values are the hex values below. For dark mode, use the system semantic colours (for example `NSColor.windowBackgroundColor`, `.labelColor`, `.secondaryLabelColor`) or values derived from the light hex. Never hard-code a light hex alone.
- Use system fonts only: SF Pro for text and SF Mono with tabular figures for numbers. Do not bundle Inter, JetBrains Mono, or any SF font file.
- The artboards' window chrome (traffic-light dots), the Wi-Fi icon, and the clock in the Main artboard belong to the mockup or macOS. Use the real window title bar and the real system menu bar, and draw none of that chrome.
- The Memory Clean free-memory line uses the Mac's real physical RAM (`ProcessInfo.processInfo.physicalMemory`), not the artboard's sample 16 GB.
- There is no per-item refresh setting. "Refresh every" and its labels ("1 s", "30 s") from the artboard are removed by project decision. Every item uses the global cadence: 2 s while the popover is open, 5 s while it is closed.

## Tokens

### Popover (380 px wide)
- Outer ground `#E4E7EB`, 16 px padding. Card `#FBFBFC`, 1 px border `rgba(0,0,0,0.12)`, radius 12, padding 12/14/8, gap 10.
- Text `#1D1D1F`. Secondary text `#5F6368`. Section divider `#E4E5E8`.
- Section title 12 px semibold, `#5F6368`, with a 14 px checkbox at the right (accent `#0F7A5F`).
- Value rows 13 px; numbers in a monospaced font with tabular figures.
- Bars: track `#E4E5E8`, fill `#14A37F`, height 4, radius 2.
- Network: up arrow `#0F7A5F` for upload, down arrow `#B4530F` for download. Sparkline 210×34: upload solid `#14A37F`, download dashed `#E0661A`.
- Buttons: primary `#1D1D1F` fill with white text, secondary white fill with `#C9CBD0` border, both radius 6.
- Footer: "Settings…" and "Quit StatusMonitor" text buttons.
- Sections in order: CPU and memory (CPU %, RAM used of total with bar), GPU, Memory pressure, Disk (Read, Write), Battery (charge with bar, health, cycle count, power source, Low Power Mode, time to full), Thermal (CPU °C), Network (sparkline, today's totals), Memory Clean (Standard, Extreme, Auto Clean with threshold line, last clean result, one-line explanation), Open at login.

### Menu bar (per item default styles)
- Light bar `#ECECEE` with `#1D1D1F` text. Dark bar `#2B2F36` with `#F2F2F4` text. Height 28, radius 6.
- Priority pills: High `#123D33` / `#7FE6C8`. Medium `#3A3320` / `#F2C46B`. Low `#2B3038` / `#B8C0CA`.
- Items: Network stacked (↑ and ↓ values), CPU value with symbol, RAM value (GB, one decimal), GPU text label, Memory pressure icon only, Disk stacked (R and W), Temperature degrees only (no C), Battery value (off by default).

### Settings (960×680)
- Window chrome: 48 px title bar `#F3F3F5`, bottom border `#E2E3E6`, traffic-light dots `#FF5F57`, `#FEBC2E`, `#28C840`, title 14 px semibold.
- Sidebar 188 px, `#F3F3F5`. Selected item: `#0F7A5F` fill, white text, radius 6. Items: Menu bar items, General, Memory Clean. "Coming later" group (greyed): Sampling, Alerts, About.
- Menu bar items list (330 px): drag handle, name and meta line, priority select, show toggle. Footnote explains that Low hides first, then Medium.
- Detail pane: light and dark preview tiles (36 px tall, radius 8), a Shows row, a Style chip row (Value, Stacked, Bars, Sparkline, Ring, Grouped; selected chip filled `#1D1D1F`), Hide when idle, Warning threshold, Critical threshold, On click.
- Memory Clean page: explanatory note box `#F2F5F8` with border `#DCE3EA` and text `#24425F`. Administrator approval row with "✓ Installed" pill (`#E3F5EF` / `#0A5A46`). Auto Clean toggle, a threshold slider from 70% to 100% in 5% steps (default 85%), a sentence showing the percentage and free GB (`physicalRAM × (100 − pct) / 100`, one decimal, GiB), tick labels, and a note that the clean waits at least 3 minutes. Two cards: Standard clean and Extreme clean, each with a "Clean now" button and a one-line description. Recent cleans table: Time, Type, Freed.

### Alerts (States artboard)
- Normal: the item's normal fill.
- Warning: a small filled triangle before the value and bold digits. Orange `#B4530F` on light, `#FF9F5A` on dark.
- Critical: the whole item filled `#C62828` with white text and a leading "!".
- Memory pressure: three icon states (Normal, Warning, Critical). The needle also moves; the state is not carried by colour alone.
- Overflow: as space shrinks, Low items hide, then Medium. High items always stay. Hidden items stay in the popover. Items come back only when there is room plus a small margin.
- Empty: an icon alone until the first sample, never 0 or N/A. Unavailable on this Mac: hidden everywhere; Settings shows it greyed with the reason and no switch.

### App icon
- Tile: dark `#16191F` with a 10% white edge stroke. Light variant `#F4F5F7` with a 10% black edge.
- Top band with a small label and a gauge glyph. Four bars in accent `#2BD4A4` (light `#0F9C78`), the last bar warm `#FF8A3D` (light `#F06A1D`), and a white polyline (light `#16191F`) ending in a dot.

### Typography
- System font (SF Pro) for UI text, monospaced with tabular figures for numbers (SF Mono). Sizes: 11 for meta text, 12 for secondary text, 13 for body, 14 for titles, 16 to 28 for headings.

## Interactive charts (new)
- Sparklines and history charts in the popover respond to pointer hover.
- Hovering shows a vertical guide, a dot on each series, and a tooltip with the time (for example "00:53:12") and the value at that time (for example "↑ 1.2 MB/s, ↓ 340 KB/s").
- The hover maps the pointer x position to the nearest sample in the series. Empty history shows no tooltip.
- Charts keep the design sizes (210×34 in the popover). Full-size history can be added later.

## Gaps between the app and the design

Status from the code, as of the latest review. This is not a visual comparison with the artboards.

Present in the code:
- Popover: the Memory Clean section, the Network daily totals line, and the Thermal section. The battery rows are present; whether they match the artboard was not checked.
- Settings window: the sidebar, the greyed "Coming later" group (Sampling, Alerts, About), and light and dark preview tiles.
- Memory Clean page: the note box, the administrator approval row, the Auto Clean switch, the threshold slider with the free-GB line, the Standard and Extreme cards, and the recent cleans table. The code's default threshold is 90%, not the 85% in this spec.
- Alert states: the warning triangle with bold digits, the filled critical memory pressure icon with its triangle and needle states, and the "!" on a critical item.
- Charts: hover tooltips on the popover charts.

Still open:
- The Settings detail pane has a Warning threshold only. There is no Critical threshold field.
- Menu bar overflow: Low items hiding first, then Medium, is not built.
- App icon: not checked against the artboard.
