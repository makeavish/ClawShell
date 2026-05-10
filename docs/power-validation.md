# Power Validation

## Normal Assertions

ClawShell normal mode uses non-privileged IOPM assertions through `IOPMAssertionCreateWithName`.

Default assertion set:

- `PreventUserIdleSystemSleep`

The default set intentionally does not include `PreventSystemSleep` because the local macOS SDK marks that assertion as unsupported. It also does not include display sleep prevention. Disk idle prevention remains a validation candidate: `PreventDiskIdle` must prove useful in `pmset` artifacts before becoming part of the default normal hold.

Run the repeatable normal assertion harness:

```sh
scripts/normal-assertion-validation.sh
```

The harness writes `before`, `during`, and `after` snapshots under `.build/power-validation/`. Each phase includes `pmset -g assertions`, `pmset -g custom`, battery state, live power settings, and optional IORegistry power-source state.

Run the timed idle harness when the machine is on the target power source and the current `pmset -g custom` sleep interval is short enough to observe:

```sh
bash scripts/timed-idle-validation.sh
```

By default, this holds the normal assertion for 90 seconds and captures `before`, `during-early`, `during-late`, and `after` snapshots. The harness does not change `pmset` settings. It records the active power source, the active profile's `sleep` threshold, whether the late snapshot exceeded that threshold, and any non-ClawShell sleep-preventing assertions in `validation-config.txt` and `non-clawshell-late-sleep-blockers.txt`. Treat a run as conclusive only when `validation-config.txt` contains `conclusive=true`.

## Manual Result Matrix

Do not claim clamshell-on-AC support from normal assertions until a real MacBook validation pass proves it. Normal assertion artifacts should fill this matrix as hardware checks are run.

| Scenario | Required artifact | Current status |
|---|---|---|
| Idle sleep on AC | Timed idle harness output while on AC | Pending timed hardware run |
| Idle sleep on battery | Timed idle harness output while on battery | Timed hold observed, but run was confounded by other sleep-preventing apps |
| AC clamshell, internal display only | Manual lid-close result plus `pmset` snapshots | Not claimed |
| AC clamshell with external display | Manual lid-close result plus `pmset` snapshots | Not claimed |
| Battery clamshell | Bag Mode spike only; normal assertions are not proof | Not claimed |

Attach generated harness directories to the relevant issue or PR when validating hardware behavior. Generated `.build/power-validation/` artifacts are local evidence and are not committed by default.

Latest local smoke for this branch: `scripts/normal-assertion-validation.sh` was run for a short hold while the machine was on battery. The sanitized `during` snapshot showed a ClawShell-owned `PreventUserIdleSystemSleep` assertion, and the `after` snapshot no longer contained ClawShell-owned assertions.

Sanitized excerpt:

```text
during/pmset-assertions.txt:
pid <redacted>(ClawShellPowerValidation): PreventUserIdleSystemSleep named: "ClawShell is holding sleep for active agent sessions"

after/pmset-assertions.txt:
<no ClawShellPowerValidation assertions present>
```

Latest battery timed run: `scripts/timed-idle-validation.sh` was run while the machine was on battery with `sleep = 1` minute and a 90 second ClawShell hold. The late snapshot showed ClawShell's `PreventUserIdleSystemSleep` still visible after the nominal 1-minute sleep setting elapsed, and the after snapshot no longer contained a ClawShell assertion. The run is not clean enough to close battery validation because other processes also held sleep assertions during the same window.
