# Temperature Provider Check

Check date: May 12, 2026

Issue: [#7](https://github.com/makeavish/ClawShell/issues/7)

Follow-up: [#25](https://github.com/makeavish/ClawShell/issues/25)

Local artifact: `.build/temperature-provider-validation/local-20260512T023358Z`

## Question

Which fresh, permission-compatible temperature source is reliable enough for Bag Mode cutoff decisions?

## Method

Added `scripts/temperature-provider-validation.sh`, a non-destructive harness that does not use sudo and does not intentionally heat hardware.

Command used:

```bash
scripts/temperature-provider-validation.sh --output-dir .build/temperature-provider-validation/local-20260512T023358Z
```

Sources tested:

- Apple `ProcessInfo.thermalState`
- `pmset -g therm`
- `powermetrics -n 1 -i 1000 --samplers thermal`
- AppleSmartBattery top-level I/O Registry temperature and update fields

Reference:

- [Apple ProcessInfo.ThermalState](https://developer.apple.com/documentation/foundation/processinfo/thermalstate)

## Local Result

| Source | Permission behavior | Freshness/timeout behavior | Numeric temperature | Closed-bag coverage | Result |
|---|---|---|---|---|---|
| `ProcessInfo.thermalState` | Works without root | Harness probe returned within 5s probe timeout; app API is not a shell command | No | Closed-bag coverage not proven; app-side coarse thermal-pressure/liveness signal only | Supplemental signal only |
| `pmset -g therm` | Works without root | Returned within the 1s command timeout | No current numeric temperature in this run | Warning history/status, not a sensor source | Not a cutoff provider |
| `powermetrics --samplers thermal` | Refused non-root execution with `powermetrics must be invoked as the superuser` | Returned within the 1s command timeout when non-root | Not available without root | Not validated in this artifact | Follow-up required |
| AppleSmartBattery I/O Registry fields | Works without root when battery service exists | Returned within the 1s command timeout; update age was 12s in this run, above the 10s freshness target | Battery pack/virtual values were present | Battery temperature does not prove CPU/package or closed-bag thermal coverage | Context only |

Captured values from `validation-config.txt`:

```text
processInfoThermalState=nominal
processInfoNumericTemperature=false
pmsetCurrentNumericTemperature=false
pmsetThermTimedOut=false
pmsetThermExitCode=0
powermetricsPermissionState=requiresRoot
powermetricsTimedOut=false
powermetricsExitCode=1
batteryTemperatureCelsius=31.95
batteryVirtualTemperatureCelsius=45.75
batteryUpdateAgeSeconds=12
batteryFreshWithin10Seconds=false
candidateSelected=none
bagModeTemperatureProviderReady=false
```

## Failure Behavior

Production Bag Mode must fail closed for:

- provider unavailable
- stale reading
- permission denied
- parse failure
- helper crash or timeout
- unsupported hardware

The harness records these as evidence fields but does not enable production behavior.

The mocked fail-closed contract is now executable in `BagModeSafetyPolicy` and covered by the portable `ClawShellCoreChecks` gate. Those checks cover warning, cutoff, stale, unavailable, permission-denied, parse-failed, helper-crashed, unsupported-hardware, timeout, coverage-insufficient, missing/invalid battery, battery floor, and hysteresis behavior. They do not select a production provider or prove helper-side sampling.

## Conclusion

No production Bag Mode temperature provider is selected from the non-root app-side sources tested.

`ProcessInfo.thermalState` is permission-compatible and useful as a supplemental app-side thermal-pressure/liveness signal, but it is coarse, non-numeric, and does not prove closed-bag coverage. `pmset -g therm` did not provide current numeric temperature evidence. AppleSmartBattery temperature is useful context when present, but it is not enough for CPU/package or closed-bag thermal risk and did not meet the 10 second freshness target in the local run. `powermetrics` was not validated as a provider in this artifact; [#25](https://github.com/makeavish/ClawShell/issues/25) must prove helper/root output, freshness, cadence, timeout, and coverage.

Production Bag Mode remains blocked until [#25](https://github.com/makeavish/ClawShell/issues/25) validates a signed-helper or equivalent provider that can supply fresh, permission-compatible thermal evidence with the required fail-closed behavior.
