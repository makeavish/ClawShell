# Development

ClawShell is currently a native macOS menu bar app skeleton built with SwiftPM.

## Requirements

- macOS 13 or newer
- Swift 6.0 or newer from Xcode or Command Line Tools

## Run Locally

```sh
swift run ClawShell
```

The app starts as an accessory menu bar process and does not request admin privileges.

## Check

```sh
scripts/validate.sh
```

The first checks cover the state/menu model, lifecycle component boundaries, persistence/privacy contracts, and a short AppKit launch smoke. AppKit behavior is intentionally thin until the detection, assertion, and integration issues add real behavior.

The local Command Line Tools environment may lack `Testing` and `XCTest`, so `ClawShellCoreChecks` remains the portable assertion gate for those machines. On CI and full toolchains with `Testing` or `XCTest`, `swift test` runs the standard SwiftPM test targets.

See [testing.md](testing.md) for the full validation matrix, contract-test structure, power snapshot harness, and manual hardware checklist.

## Local Data

ClawShell stores local state under `~/Library/Application Support/ClawShell/`:

- `settings.json` contains versioned settings.
- `logs/audit.jsonl` contains bounded local audit events.

Config exports exclude logs, runtime tokens, helper ownership state, cwd hashes, and hook payloads. Custom executable paths can still reveal local machine details, so exported config should be shared carefully.
