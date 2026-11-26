# Memory Clean

Modelled on FIPLAB's Memory Clean 2/3, with the safety rails in the spec.

**Status:** the decision logic, the step runner, the sudoers executor, and the persistence are implemented and unit-tested. The UI, the Auto Clean scheduler, Memory Hogs, Auto Clean on Close, and the sudoers installer are **not yet built**. See `LIMITATIONS.md`.

## Privilege mechanism

`/usr/sbin/purge` requires root. On this machine a non-root run fails with `Unable to purge disk buffers: Operation not permitted`.

**Chosen mechanism: a sudoers rule, `NOPASSWD`, for `/usr/sbin/purge` only.**

- The rule file is `/etc/sudoers.d/statusmonitor-purge`, containing:
  `<user> ALL=(root) NOPASSWD: /usr/sbin/purge ""`
  The `""` means the command takes no arguments. A bare `/usr/sbin/purge` would allow any arguments.
- The app runs `sudo -n /usr/sbin/purge`. The `-n` flag means it never prompts. If the rule is missing, `sudo` exits non-zero immediately.
- Availability is checked with `sudo -n -l /usr/sbin/purge` (exit 0 = available). It never prompts, and the result is cached until the rule is installed or removed.

**Why this and not the spec's preference (SMJobBless):** SMJobBless and SMAppService both require a Developer ID code-signing identity to match. This machine has **0 valid signing identities**, so the helper cannot be installed or verified here. SMJobBless is also deprecated. AuthorizationExecuteWithPrivileges would prompt again once its credential expires (about 5 minutes), which breaks "never prompt on a timer". The user chose the sudoers rule.

**Installation (planned, not yet built):** the rule is written only after an explicit click on "Install purge permission". One administrator prompt is shown. The installer writes a temporary file, validates it with `visudo -cf`, and only then installs it with `install -m 0440 -o root`. A matching "Uninstall" action removes the file. Installing a broken sudoers file can break `sudo` for the whole system, so the `visudo` check is mandatory.

**Helper unavailable:** an Auto Clean tick logs `skipped: helper not available` and never prompts. A manual Clean shows the install state.

## Exact commands

| Clean | Steps (each measured and logged) |
|---|---|
| Standard | `sudo -n /usr/sbin/purge` |
| Extreme | `sudo -n /usr/sbin/purge` → `memory_pressure -l warn` → `sudo -n /usr/sbin/purge` (second pass) |

Extreme Clean reports the *measured* available-memory delta for each step. It does not assert a fixed GB figure. Whether `memory_pressure -l warn` needs root has not been verified; if it does, its sudoers line must be added.

## Available memory

`available = (free + inactive + purgeable pages) × page size`. This single formula is used for both the clean report and Auto Clean.

## Cooldown and the 180 s floor

- Auto Clean cooldown: **180 seconds, a hard floor**. It cannot be configured below this, and there is no option to disable it.
- The cooldown runs from the last clean, which is persisted in UserDefaults (`remediation.lastCleanAt`), so it survives a restart.
- A last-clean time in the future (clock moved backwards) is refused until the caller clamps it to now and stores the result. Clamping on every check would block cleaning forever.
- Skipped attempts are logged with the reason, for example `cooldown`, `free memory above threshold`, or `helper not available`.

## Known limitation

`purge` flushes the disk cache and frees **inactive file-backed memory only**. It does **not** free wired memory, and it does not stop a runaway process. The UI action is labelled "Purge inactive memory", not "Free RAM".
