# Testing

ClawShell uses two automated gates today:

- `ClawShellCoreChecks` is the portable local gate. It runs on the current Command Line Tools environment even when `Testing` and `XCTest` are unavailable.
- SwiftPM test targets are the standard test home for CI and full Xcode toolchains.

Run the complete local validation script:

```sh
scripts/validate.sh
```

The script runs:

- `swift build`
- `swift run ClawShellCoreChecks`
- `swift run ClawShell --smoke-test`
- `swift test` only when the active toolchain can discover real ClawShell tests

If the local toolchain cannot import `Testing` or `XCTest`, `swift test` fails loudly instead of passing with zero discovered tests.

## Unit Test Matrix

`Tests/ClawShellCoreTests` is the home for unit tests. As the implementation lands, it should cover:

- Session transition matrix
- PID reuse and process restart dedupe
- Out-of-order hook events
- Grace timer reset and non-reset rules
- Manual override precedence and persistence
- Safety transitions, stale sensors, unavailable sensors, and hysteresis
- Settings migration, atomic write, corrupt settings recovery
- Export redaction and exclusion rules

## Contract Test Matrix

`Tests/ClawShellContractTests` is the home for integration and contract tests. Fixture slots already exist under `Tests/ClawShellContractTests/Fixtures/`.

Future contract coverage should include:

- Adapter redaction: fail if payloads or logs contain prompts, tool args, cwd, transcript paths, or environment values
- Adapter no-op behavior when ClawShell is not running
- Control endpoint auth failure, replay rejection, and rate limiting
- Config patcher fixtures for Claude Code and Codex CLI
- Config merge/removal preserving unrelated user config
- CLI command behavior

## Power Snapshot Harness

Use the non-destructive snapshot harness before and after power-management experiments:

```sh
scripts/pmset-snapshot.sh
```

The harness captures `pmset` and power-state diagnostics without changing power settings. It must not be used as proof that ClawShell blocks clamshell sleep; it only records state for validation artifacts.

## Manual Hardware Checklist

Hardware validation is gated and must be run intentionally on supported machines. Do not intentionally overheat hardware; thermal cutoff validation uses mocks or simulated sensor providers.

- AC lid close
- Battery lid close
- Reboot while held
- App crash while held
- Helper crash and restart
- Helper upgrade mid-hold
- Concurrent power setting changes by the user or system

For each manual case, attach:

- Exact command or build used
- `pmset -g custom`
- `pmset -g assertions`
- Relevant IORegistry state if available
- Whether lid-close sleep was actually blocked
- Rollback command
- State after reboot, when applicable
