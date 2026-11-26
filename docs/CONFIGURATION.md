# Configuration

Every user-facing setting, its default, its range, where it is stored, and whether the app reads it today.

**Status key:**
- **Implemented:** a control in the app writes the value, and the app reads it.
- **Partly implemented:** the value is stored and editable, but the behaviour it names is not built.
- **Fixed:** the value is built into the app and cannot be changed.

Settings are stored in UserDefaults under the app's domain, `com.example.StatusMonitor` (`defaults read com.example.StatusMonitor`), unless the table says otherwise. See `LIMITATIONS.md` for what was verified on the test machine.

## Menu bar items and popover

| Setting | Default | Range | Key | Status |
|---|---|---|---|---|
| Show CPU item | on | on/off | `showCPU` | Implemented. Menu bar items > CPU; also the checkbox on the popover CPU card. |
| CPU item value | CPU % | CPU % / RAM GB | `cpuMode` | Implemented. Menu bar items > CPU > Shows. "RAM GB" shows used RAM, labelled RAM. |
| Show network item | on | on/off | `showNetwork` | Implemented. |
| Show other items in the menu bar | GPU on. Memory pressure, disk I/O, battery and temperature off. | on/off, per item | `hiddenMenuBarItems` | Implemented. Each item's Show toggle in the list. Items the Mac does not support are never shown. |
| Show card in the popover | on, where the Mac supports the metric | on/off, per metric | `collectorOverrides` | Implemented. Menu bar items > [item] > Show card in the popover. Hidden where the Mac does not support the metric. |
| Item order | CPU, GPU, Memory pressure, Network, Disk I/O, Battery, Temperature | drag to reorder | `menuBarOrder` | Implemented. The RAM entry is not listed; RAM is shown inside the CPU item. |
| Priority | CPU High. Network, GPU, Battery Medium. Memory pressure, Disk I/O, Temperature Low. | High / Medium / Low | `menuBarPriorities` | Partly implemented. The priority is stored and editable. It does not hide items: hiding when the menu bar is full is not built. |
| Style | Network and Disk I/O: stacked. Memory pressure: icon only. CPU, GPU, Temperature, Battery: value. | Per item, from the styles that item supports | `menuBarItemConfigs` | Implemented. Value, stacked, bars, sparkline, ring, grouped and icon only, depending on the item. |
| Hide while idle | Disk I/O on. Network off. | on/off | `menuBarItemConfigs` | Implemented for network and disk I/O only. |
| Idle threshold | 100,000 bytes/s. The field shows KB/s (1024 steps), so the default displays as about 97.7. | Any value of 0 or more | `menuBarItemConfigs` | Implemented, for the items that offer hide while idle. |
| Warning threshold | Off. When switched on, the field starts at: network 50 MB/s, disk I/O 500 MB/s, temperature 90 °C, other items 80%. | Any value of 0 or more | `menuBarItemConfigs` | Implemented. One threshold only: it sets the warning state. There is no critical threshold in Settings. MB/s uses 1024 steps. |
| On click | Show popover | Show popover / Open Activity Monitor / Nothing | `menuBarItemConfigs` | Implemented. |
| Battery details | All shown | Eight on/off toggles: charge row, charging or discharging watts, battery % in the menu bar, health, cycle count, power state, Low Power Mode, time remaining | `hiddenBatteryDetails` | Implemented. General > Battery details. The "Battery % in menu bar" toggle also controls whether the battery item appears in the bar. |
| Include loopback (lo0) | off | on/off | `includeLoopback` | Implemented. General > Network. |
| Network interfaces | All active interfaces | Comma-separated names, for example `en0, utun3` | `allowedInterfaces` | Implemented. General > Network. A blank field counts all active interfaces. |
| Theme | System | System / Light / Dark | `appearance` | Implemented. General > Theme. Applies to the popover and the Settings window. |
| Open at login | off | on/off | Login item, held by the system (`SMAppService`), not UserDefaults | Implemented. General > Startup, and the popover row. |
| Sampling cadence | 2 s while the popover is open, 5 s while it is closed | Fixed | not stored | Fixed. There is no per-item refresh rate. Every item uses the same cadence. |

## Memory Clean

| Setting | Default | Range | Key | Status |
|---|---|---|---|---|
| Auto Clean on/off | off | on/off | `autoCleanEnabled` | Implemented. Settings > Memory Clean, and the popover switch. |
| Auto Clean threshold | 85 (the code currently uses 90; see below) | 70% to 100%, in 5-point steps | `autoCleanThresholdPercent` | Implemented. Slider in Settings > Memory Clean. The range and snapping are built. The default changes to 85 in the planned change. |
| Auto Clean cooldown | 180 s, a floor that cannot be configured or turned off | Fixed | `remediation.lastCleanAt` holds the time of the last clean | Implemented at 180 s. The planned change doubles it to 1800 s after an ineffective clean. |

Planned fixed values, in the change in progress (not in the code yet): sustain period 30 s of measured time, re-arm margin 5 points below the threshold, ineffective clean under 256 MiB freed, pause after 3 failed cleans. See `MEMORY_CLEAN.md`.

The default threshold is 90 in the code today (`AutoCleanThreshold.defaultPercent`). The documented default is 85, which the planned change sets.

## Helper

| Setting | Default | Status |
|---|---|---|
| Sudoers purge rule | Not installed | Implemented. Install… and Remove in Settings > Memory Clean. The rule file is `/etc/sudoers.d/statusmonitor-purge`. The install path has not been run on a real Mac. See `MEMORY_CLEAN.md`. |

## Not in the app

These are not configurable, and the app has no code for them:

- Rules, with their thresholds, actions, cooldowns, and scripts.
- A per-item refresh rate. This was removed by decision.
- Segment separator and compact mode.
- Extreme Clean on/off and dry-run.
- An Auto Clean type (standard or extreme).
- Memory Hogs and its list size.
- Auto Clean on Close.
- Freed-memory notifications.
