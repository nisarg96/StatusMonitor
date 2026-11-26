# Memory Clean

Modelled on FIPLAB's Memory Clean 2/3, with the safety rails in the spec.

## Status

Checked against the code in this review.

**Built:**
- The Standard and Extreme clean steps. Each step measures available memory before and after, and logs its exit code.
- The sudoers executor (`SudoersPurgeExecutor`), the rule installer and remover (`SudoersInstaller`), and the rule text (`SudoersRule`).
- The Auto Clean decision (`AutoCleanDecision`) and the Auto Clean scheduler (`AutoCleanCoordinator`). The scheduler runs on every refresh of the monitor.
- The cooldown timestamp, stored as `remediation.lastCleanAt` in UserDefaults.
- The Settings page, Settings > Memory Clean: the administrator approval row with **Install…** and **Remove**, the Auto Clean switch, the threshold slider (70% to 100% in 5-point steps), the Standard and Extreme cards with **Clean now** buttons, and the recent cleans list.
- The popover Memory Clean section: Standard clean and Extreme clean buttons, and an Auto Clean switch.

**Not built:** Memory Hogs and Auto Clean on Close.

**Not verified on a real Mac:** the install path (the administrator prompt, the `visudo` check, and the `install` step), a real Standard or Extreme clean, and whether `memory_pressure -l warn` needs root. See `LIMITATIONS.md`.

**Planned, not in the code yet:** the Auto Clean rule changes described under "Auto Clean" below.

## Privilege mechanism

`/usr/sbin/purge` requires root. On the test machine a non-root run fails with `Unable to purge disk buffers: Operation not permitted`.

**Chosen mechanism: a sudoers rule, `NOPASSWD`, for `/usr/sbin/purge` only.**

- The rule file is `/etc/sudoers.d/statusmonitor-purge`, containing:
  `<user> ALL=(root) NOPASSWD: /usr/sbin/purge ""`
  The `""` means the command takes no arguments. A bare `/usr/sbin/purge` would allow any arguments.
- The app runs `sudo -n /usr/sbin/purge`. The `-n` flag means it never prompts. If the rule is missing, `sudo` exits non-zero immediately.
- Availability is checked with `sudo -n -l /usr/sbin/purge` (exit 0 = available). It never prompts. The result is cached until the rule is installed or removed, and the cache is cleared on each change.

**Why this and not the spec's preference (SMJobBless):** SMJobBless and SMAppService both require a Developer ID code-signing identity to match. The test machine has **0 valid signing identities**, so a signed helper cannot be installed or verified there. SMJobBless is also deprecated. AuthorizationExecuteWithPrivileges would prompt again once its credential expires (about 5 minutes), which breaks "never prompt on a timer". The project chose the sudoers rule.

**Installation:** the rule is written only after an explicit click on **Install…** in Settings > Memory Clean. One administrator prompt is shown. Root runs one script:

1. `mktemp` creates a root-owned temporary file in root's home directory, created exclusively with mode 0600.
2. The rule line is written into that file.
3. `visudo -cf` checks that exact file. If the check fails, nothing is installed.
4. `install -m 0440 -o root -g wheel` copies the checked file to `/etc/sudoers.d/statusmonitor-purge`, and the temporary file is removed.

**Removal:** **Remove** runs `rm -f` on the rule file under one administrator prompt.

Installing a broken sudoers file can break `sudo` for the whole system, so the `visudo` check is mandatory.

**Helper unavailable:** when the rule is missing, Auto Clean does not clean and never prompts. Its decision reports `helper not available`. A manual clean with the rule missing does not prompt either. It is logged as skipped, and the approval row shows "Not installed".

## Exact commands

| Clean | Steps (each measured and logged) |
|---|---|
| Standard | `sudo -n /usr/sbin/purge` |
| Extreme | `sudo -n /usr/sbin/purge` → `memory_pressure -l warn` → `sudo -n /usr/sbin/purge` (second pass) |

Extreme Clean reports the *measured* available-memory delta for each step. It does not assert a fixed GB figure.

The middle step runs `/usr/bin/memory_pressure -l warn` directly, without `sudo`, and it is not covered by the sudoers rule. Whether that command needs root has not been verified. If it does, the step fails, and its exit code appears in the log.

## Memory measures

There are two different measures, and they are not interchangeable.

- **Used RAM** is app memory, plus wired memory, plus compressed memory. App memory is internal pages minus purgeable pages. File-backed cache is not counted. This is the measure that Auto Clean's trigger uses, and the "RAM GB" value in the menu bar uses the same definition.
- **Available memory** is `(free + inactive + purgeable pages) × page size`. This single formula is used for the clean report and for the measured delta of each step. It is not used for the Auto Clean trigger.

## Auto Clean

### Trigger

- Auto Clean is off by default.
- The trigger is used RAM as a percentage of physical RAM. It is compared with the threshold on every refresh of the monitor, which runs every 2 s while the popover is open and every 5 s while it is closed.
- The threshold is a slider from 70% to 100% in 5-point steps. The default in the code is **90%**. The planned default is **85%**.

### Current behaviour (in the code)

- A Standard clean starts on the first refresh where used RAM is at or above the threshold, if the helper is available and the cooldown has passed.
- The cooldown is a fixed 180 s from the last clean. It cannot be configured below 180 s, and it cannot be turned off.
- The clean runs in the background. Auto Clean and manual cleans each have their own in-flight guard, so an Auto Clean can run while a manual clean is running, and the reverse.

### Planned behaviour (in progress, not in the code yet)

- **Sustain:** used RAM must stay at or above the threshold for 30 s of measured time before a clean starts. The time is measured from timestamps, not counted in refreshes.
- **Default threshold:** 85%.
- **Re-arm:** after a clean, Auto Clean does not fire again until used RAM falls 5 points below the threshold.
- **Cooldown:** 180 s after a clean. After an ineffective clean, meaning under 256 MiB of available memory freed, the cooldown doubles, up to a maximum of 1800 s. How the cooldown returns to 180 s after an effective clean is not yet specified.
- **Pause:** after 3 failed cleans, Auto Clean pauses. What counts as a failed clean, and how a pause ends other than by relaunch, is not yet specified.
- **Shared guard:** an Auto Clean and a manual clean share one in-flight guard. A clean started by hand blocks Auto Clean while it runs, and the reverse.
- **State:** the backoff, the failure count, and the pause live in memory only. They reset on relaunch. The last clean time stays in UserDefaults as it is today.

### Known limitation: the trigger and the purge measure different things

The trigger uses used RAM, which does not include file-backed cache. `purge` releases inactive file cache, and that cache is not part of used RAM. A clean therefore seldom lowers used RAM by much. Used RAM can stay at or above the threshold after a clean, and Auto Clean can keep firing once each cooldown ends. The backoff in the planned change limits how often this happens. It does not change what `purge` can free.

## Cooldown and the clock

- The cooldown runs from the last clean. That time is persisted in UserDefaults (`remediation.lastCleanAt`), so it survives a restart.
- A last-clean time in the future (the clock moved backwards) is clamped to the current time on the next Auto Clean check. The clamped value is stored, so the cooldown counts forward from now. Clamping on every check would block cleaning forever, so it is done once.

## Logging

- Each clean attempt writes one line to `~/Library/Logs/StatusMonitor/remediation.log`. The line starts with an ISO 8601 timestamp.
- A clean that runs is logged with its trigger (`manual` or `auto`), its total measured delta, and each step's exit code and delta.
- A clean that is refused is logged as `skipped: <reason>`. The reason is `helper not available` in the current code.
- Skipped Auto Clean checks (Auto Clean off, RAM below the threshold, or cooldown) are not logged in the current code.
- The recent cleans list in Settings keeps the last 10 cleans in memory. It is empty after a relaunch.
- An "Open Log" button is not built.

## Known limitation: what purge frees

`purge` flushes the disk cache and frees **inactive file-backed memory only**. It does **not** free wired memory, and it does not stop a runaway process. The UI names the actions "Standard clean" and "Extreme clean". The Settings page and the popover both state that the clean frees inactive file cache only, and that memory used by open apps stays as it is.
