# Configuration

Every user-configurable parameter, its default, its range, and where it is persisted.

**Status:** only the parameters marked **Implemented** are wired to a value that the app reads today. Everything else is specified but not yet built. See `LIMITATIONS.md`.

Persistence keys are in UserDefaults for the app's domain (`defaults read com.example.StatusMonitor`).

## Status bar and metrics

| Parameter | Default | Range | Key | Status |
|---|---|---|---|---|
| Show CPU | on | on/off | `showCPU` | Implemented |
| CPU display | percent | percent / used RAM (GB) | `cpuMode` | Implemented |
| Show network | on | on/off | `showNetwork` | Implemented |
| Include loopback (lo0) | off | on/off | `includeLoopback` | Implemented |
| Network interfaces | all active | comma-separated names | `allowedInterfaces` | Implemented |
| Show GPU, memory pressure, disk I/O, battery, thermal | on if the Mac supports it | on/off (hidden when unsupported) | `collectorOverrides` | Implemented |
| Refresh interval | 2 s open / 5 s closed | 1–10 s | not yet | **Not implemented** (fixed cadence) |
| Segment separator, compact mode | `·`, verbose | — | not yet | **Not implemented** |

## Memory Clean

| Parameter | Default | Range | Persisted as | Status |
|---|---|---|---|---|
| Auto Clean on/off | off | on/off | not yet | **Logic implemented, no UI or scheduler** |
| Auto Clean threshold | 100 MB | 25–2457 MB (warning above 25% of RAM) | not yet | **Range and warning implemented; no UI** |
| Auto Clean type | standard | standard / extreme | not yet | **Not implemented** |
| Auto Clean cooldown | 180 s | fixed floor, not configurable | `remediation.lastCleanAt` | Implemented (floor enforced) |
| Extreme Clean on/off | off | on/off | not yet | **Not implemented** |
| Extreme Clean dry-run | on | on/off | not yet | **Not implemented** |
| Memory Hogs list size | 5 | 3 / 5 / 10 | not yet | **Not implemented** |
| Auto Clean on Close | off | on/off | not yet | **Not implemented** |
| Freed-memory notification | on | on/off | not yet | **Not implemented** |

## Rules

| Parameter | Default | Range | Persisted as | Status |
|---|---|---|---|---|
| Rule definition (metric, comparator, threshold, sustain, action, cooldown, dry-run, enabled) | dry-run on, disabled | see below | `remediation.rules` (JSON) | Domain and persistence implemented; **no UI** |
| Rule cooldown | user value | floor 60 s notify / 300 s script / 180 s clean | inside the rule | Floor enforced in code |
| Rule runtime (streak, last fired) | 0 / none | — | `remediation.runtime.<uuid>` | Implemented |
| Global script rate limit | 1 per 600 s | fixed, not disableable | `remediation.lastScriptRunAt` | Logic implemented; no script runner yet |
| First script rule confirmation | not confirmed | once | `remediation.confirmedScriptRules` | Stored; no modal yet |
| First Extreme Clean confirmation | not confirmed | once | `remediation.confirmedExtremeClean` | Stored; no modal yet |

Rule metrics: CPU %, memory pressure, disk free GB / %, swap used GB, battery health %. Comparators: `>`, `≥`, `<`, `≤`. Actions: notify, run script, clean (standard or extreme).

## Helper

| Parameter | Default | Status |
|---|---|---|
| Sudoers purge rule | not installed | Availability check implemented; installer **not yet built** |
