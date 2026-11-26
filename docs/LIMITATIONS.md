# Limitations

This file records what could not be verified or made to work reliably on the test machine. A hidden metric is always preferred to a wrong one, so unsupported features are hidden at runtime rather than shown as 0 or N/A.

## Test machine

MacBook Air (Apple M1, `MacBookAir10,1`), macOS 27.3. It is fanless and has a battery. Desktop Macs, Intel Macs, and Macs with fans have not been tested.

## Collectors

The statuses below are the results recorded on the test machine. The latest code review checked that each collector exists in the code. It did not repeat the hardware comparisons.

| Collector | Status on test machine | Notes |
|---|---|---|
| CPU, RAM, Network | Verified | Network matched the kernel `en0` byte counter (46.8 MB sampled vs 47 MB measured over the same window). |
| Memory pressure | Verified | `sysctl kern.memorystatus_vm_pressure_level` = 1 (Normal) matched the app. Warning and Critical were not exercised. |
| Battery | Verified | Charge 23%, cycle count 1, and power source all matched `system_profiler SPPowerDataType` and `ioreg`. Health is clamped to 100%: the raw max capacity (4848) is above design (4800) on this battery, so the value is not a real health reading here. |
| Disk I/O | Partially verified | Write spike of about 337 MB/s was observed during a `dd` write. The read and write counters are summed across `IOBlockStorageDriver` instances. The exact figures were not cross-checked with a second tool. |
| GPU | Partially verified | Values of 0–20% were reported under light load. They were not compared with Activity Monitor's GPU History. The GPU reads `Device Utilization %` on this Mac. VRAM is not shown because Apple Silicon does not report `vramUsedBytes` and `vramFreeBytes`, so that row is hidden. |
| Thermal | Partially verified | CPU temperature (about 67–72 °C under load) was read via the SMC. It was not compared with an external SMC tool. Fan rows are hidden because `FNum` is absent on this fanless Mac. Fan RPM rendering has not been exercised on real hardware with fans. |
| Memory Clean | Not verified | See "Memory Clean: status" below. |

## Known limitations

- **Thermal sensor keys vary by generation.** The app discovers CPU sensors by prefix (`TC`, `Tp`, `Te`) and takes the hottest plausible reading. It does not hardcode `TCMz` or `TC0D`. The discovered set has not been validated against Intel hardware.
- **SMC requires a non-sandboxed build.** The app is not sandboxed. `compile.sh` ad-hoc signs the bundle and sets no entitlements. A sandboxed build cannot open `AppleSMC`, and the thermal section is then hidden automatically.
- **32-bit network counters.** `if_data` counters wrap at 4 GiB. At a 2 s sample interval this only matters above about 2 GB/s on a single interface. The spec mandates `getifaddrs`, so the 64-bit `NET_RT_IFLIST2` counters are not used.
- **Disk counters may double-count.** Summing across all `IOBlockStorageDriver` services can double-count if a virtual disk stacks on another driver. Physical disks are the main case.
- **Battery health depends on the registry.** Health comes from `AppleRawMaxCapacity` (or `NominalChargeCapacity`) over `DesignCapacity`, and it is clamped to 100%. Some batteries report values that clamp, which shows as 100%.
- **Metric sampling happens on the main thread.** The GPU, disk, battery, and memory-pressure reads are synchronous IOKit and sysctl calls. They are cheap, but they run on the main thread. Only the SMC thermal read runs in the background, and the launch-time capability probe also runs off the main thread.
- **Sendable warnings in the composition root.** The launch-time capability probe is handed to a background queue. The Swift 6 compiler may report non-Sendable captures there. This review did not build the project, so the current warnings are not confirmed.
- **Menu bar overflow is not handled.** Priorities are stored, but nothing hides items when the menu bar is full. macOS gives apps no public way to measure free menu bar width.

## Memory Clean: status

**Built, with unit tests under `Tests/StatusMonitorCoreTests/`:** the Auto Clean decision (threshold, cooldown, and skip reasons), the Auto Clean coordinator (helper check off the caller's thread, priming at launch, clock moved back), the Standard and Extreme step runner with per-step measured deltas, the available-memory formula, the sudoers executor, the sudoers rule text and install script, the purge permission view model, the Memory Clean view model, and the persisted cooldown timestamp. The sudoers executor test that calls `/usr/bin/sudo -n -l` runs real `sudo`, but it does not prompt.

**Built, without automated tests of the on-screen behaviour:** the Settings page, the popover Memory Clean section, and the recent cleans list. These have not been checked by hand in this review.

**Not built:**
- Memory Hogs (listing processes).
- Auto Clean on Close.
- A button that opens the remediation log.
- The Auto Clean rule changes described in `MEMORY_CLEAN.md` (sustain, re-arm, backoff, pause, and shared in-flight guard). These are planned, not in the code.

**Known limitation of Auto Clean:** the trigger uses used RAM, which does not include file-backed cache. `purge` releases inactive file cache, so a clean seldom lowers used RAM by much, and Auto Clean can keep firing after each cooldown. See `MEMORY_CLEAN.md`.

**Cannot be verified on the test machine, and needs a manual check on a Mac:**
- The install path. Install… and Remove run one administrator prompt each, and the install runs `visudo -cf` before copying the rule into `/etc/sudoers.d/`. This has not been run on a real Mac.
- A real Standard or Extreme clean. The rule has not been installed on the test machine, so the measured deltas have not been observed.
- Whether `memory_pressure -l warn` needs root. It runs without `sudo` in the code, and this has not been verified.
- Any signed helper (SMJobBless or SMAppService). The test machine has 0 valid code-signing identities, so these are out of scope.
