# Bag Mode Primitive Matrix

Check date: May 12, 2026

Issue: [#7](https://github.com/makeavish/ClawShell/issues/7)

Follow-up: [#29](https://github.com/makeavish/ClawShell/issues/29)

Harness artifact: [PR #22](https://github.com/makeavish/ClawShell/pull/22)

## Question

Is `pmset disablesleep` reliable enough across ClawShell's required Bag Mode matrix?

## Current Evidence

PR #22 added `scripts/bag-mode-primitive-validation.sh`, a dedicated harness for the candidate primitive. The harness can:

- run a non-mutating baseline capture
- require root plus explicit acknowledgement for mutating runs
- record the previous `disablesleep` value before applying the candidate primitive
- capture `pmset -g custom`, `pmset -g assertions`, IORegistry state, and redacted metadata
- write rollback instructions before reboot-held validation
- restore and verify the pre-run `disablesleep` value in non-reboot mutating runs
- preserve existing evidence when continuing a run

This proves the evidence workflow exists. It does not prove the primitive is reliable.

## Missing Evidence

No pass/fail matrix is recorded yet for the primitive-only cases available before the signed helper prototype:

- macOS 13, 14, and 15+ where available
- Apple Silicon, and Intel if Intel support remains in scope
- AC and battery
- internal-only, external display, and no-external-display cases where physically available
- open, closed, and reopen recovery behavior
- app quit, app crash, and reboot while held lifecycle cases

Helper-dependent cases, such as helper restart and helper upgrade mid-hold, are deferred until #27 produces a signed helper prototype. Until then, each helper-only lifecycle row must be marked `N/A` or `deferred until #27` in `manual-result.md`.

Each case still needs the exact command applied, rollback command, `pmset -g custom`, `pmset -g assertions`, relevant IORegistry state, lid-close result, reboot state or explicit `N/A`, and a pass/fail/inconclusive conclusion in `manual-result.md`. Attach evidence directories to #29 and summarize or cross-link the result on #7.

## Conclusion

The primitive remains unproven. Production Bag Mode must stay blocked until [#29](https://github.com/makeavish/ClawShell/issues/29) records the real hardware matrix or the TDD switches to a different proven primitive.
