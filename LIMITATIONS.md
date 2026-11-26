# Limitations

This file records what could not be verified or made to work reliably on the test machine. A hidden metric is always preferred to a wrong one, so unsupported features are hidden at runtime rather than shown as 0 or N/A.

## Test machine

MacBook Air (Apple M1, `MacBookAir10,1`), macOS 27.3. It is fanless and has a battery. Desktop Macs, Intel Macs, and Macs with fans have not been tested.

## Collectors

| Collector | Status on test machine | Notes |
|---|---|---|
| CPU, RAM, Network | Verified | Network matched the kernel `en0` byte counter (46.8 MB sampled vs 47 MB measured over the same window). |
| Memory pressure | Verified | `sysctl kern.memorystatus_vm_pressure_level` = 1 (Normal) matched the app. Warning and Critical were not exercised. |
| Battery | Verified | Charge 23%, cycle count 1, and power source all matched `system_profiler SPPowerDataType` and `ioreg`. Health is clamped to 100%: the raw max capacity (4848) is above design (4800) on this battery, so the value is not a real health reading here. |
| Disk I/O | Partially verified | Write spike of ~337 MB/s was observed during a `dd` write, and the read/write counters are summed across `IOBlockStorageDriver` instances. The exact figures were not cross-checked with a second tool. |
| GPU | Partially verified | Values of 0–20% were reported under light load. They were not compared with Activity Monitor's GPU History. The GPU reads `Device Utilization %` on this Mac. VRAM is not shown because Apple Silicon does not report `vramUsedBytes` and `vramFreeBytes`, so that row is hidden. |
| Thermal | Partially verified | CPU temperature (about 67–72 °C under load) was read via the SMC. It was not compared with an external SMC tool. Fan rows are hidden because `FNum` is absent on this fanless Mac. Fan RPM rendering has not been exercised on real hardware with fans. |

## Known limitations

- **Thermal sensor keys vary by generation.** The app discovers CPU sensors by prefix (`TC`, `Tp`, `Te`) and takes the hottest plausible reading. It does not hardcode `TCMz` or `TC0D`. The discovered set has not been validated against Intel hardware.
- **SMC requires a non-sandboxed build.** The app is not sandboxed. A sandboxed build cannot open `AppleSMC`, and the thermal section is then hidden automatically. No temporary-exception entitlement is requested.
- **32-bit network counters.** `if_data` counters wrap at 4 GiB. At a 2 s sample interval this only matters above about 2 GB/s on a single interface. The spec mandates `getifaddrs`, so the 64-bit `NET_RT_IFLIST2` counters are not used.
- **Disk counters may double-count.** Summing across all `IOBlockStorageDriver` services can double-count if a virtual disk stacks on another driver. Physical disks are the main case.
- **Battery health depends on the registry.** Health comes from `AppleRawMaxCapacity` (or `NominalChargeCapacity`) over `DesignCapacity`, and it is clamped to 100%. Some batteries report values that clamp, which shows as 100%.
- **Metric sampling happens on the main thread.** The GPU, disk, battery, and memory-pressure reads are synchronous IOKit and sysctl calls. They are cheap, but they run on the main thread. Only the SMC thermal read runs in the background.
- **Sendable warnings in the composition root.** The launch-time capability probe is handed to a background queue. The Swift 6 compiler reports non-Sendable captures there. The behaviour is correct; the warnings are not yet silenced.

## Layer 2 and Layer 3 (rules and Memory Clean): status

Built and unit-tested (148 tests pass): rule state machine, sustain streak, cooldown with floors, cooldown that survives threshold and action edits, global script rate limit, Auto Clean decision with its 180 s floor, available-memory formula, Standard and Extreme step runner with per-step measured deltas, sudoers executor (unavailable path tested against the real `sudo -n`), rule and runtime persistence.

**Not built yet** (do not assume these work):
- Rules and Memory Clean UI (Rules tab, Memory Clean tab, rule-creation sheet, confirmation modals).
- Rule evaluation loop wired to the 2 s tick (`EvaluateRulesUseCase`).
- Script runner (`Process` with `/bin/zsh -c`, timeout, logging, script-path validation).
- Notifications (`UNUserNotificationCenter`).
- Swap and disk-free metric adapters, needed by the swap and disk rule metrics.
- Memory Hogs (`proc_listpids` / `proc_pidinfo`) and Auto Clean on Close.
- Auto Clean scheduler and its free-memory adapter wiring.
- Sudoers installer and uninstaller (`visudo -cf` validation, one admin prompt).
- Remediation log file (JSONL) and the "Open Log" button.

**Cannot be verified on this test machine:**
- A real Standard or Extreme Clean. The purge rule cannot be installed without the user's administrator password, so the measured delta has not been observed.
- Whether `memory_pressure -l warn` needs root. Not verified.
- Any signed helper (SMJobBless or SMAppService). There are 0 valid code-signing identities, so these are out of scope.
- PID reuse protection for Auto Clean on Close. Not implemented yet.
