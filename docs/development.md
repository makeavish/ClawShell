# Development

ClawShell is currently a native macOS menu bar app skeleton built with SwiftPM.

## Requirements

- macOS 13 or newer
- Apple Swift toolchain from Xcode or Command Line Tools

## Run Locally

```sh
swift run ClawShell
```

The app starts as an accessory menu bar process and does not request admin privileges.

## Check

```sh
swift run ClawShellCoreChecks
```

The first checks cover the state/menu model and lifecycle component boundaries. AppKit behavior is intentionally thin until the detection, assertion, and integration issues add real behavior.

The local Command Line Tools environment currently lacks `XCTest`, so the full XCTest suite belongs to the dedicated test-harness issue.
