#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> swift --version"
swift --version

echo "==> swift build"
swift build

echo "==> swift run ClawShellCoreChecks"
swift run ClawShellCoreChecks

echo "==> swift run ClawShell --smoke-test"
swift run ClawShell --smoke-test

echo "==> contract fixture slot check"
for slot in adapters cli config-patchers control-server power; do
    if [[ ! -d "Tests/ClawShellContractTests/Fixtures/$slot" ]]; then
        echo "Missing contract fixture slot directory: $slot" >&2
        exit 1
    fi
done

echo "==> shell script syntax"
for script in scripts/*.sh; do
    bash -n "$script"
done

echo "==> bag mode primitive harness smoke"
bag_mode_smoke_dir="$(mktemp -d)"
bag_mode_smoke_error="$(mktemp)"
test_list_output=""
test_list_error=""
trap '[[ -n "$test_list_output" ]] && rm -f "$test_list_output"; [[ -n "$test_list_error" ]] && rm -f "$test_list_error"; rm -f "$bag_mode_smoke_error"; rm -rf "$bag_mode_smoke_dir"' EXIT

if scripts/bag-mode-primitive-validation.sh --output-dir "$bag_mode_smoke_dir/missing-ack" --apply >"$bag_mode_smoke_error" 2>&1; then
    echo "Bag Mode primitive harness allowed --apply without acknowledgement" >&2
    exit 1
fi
if ! grep -q -- "--apply requires --i-understand-this-changes-power-settings" "$bag_mode_smoke_error"; then
    cat "$bag_mode_smoke_error" >&2
    exit 1
fi

scripts/bag-mode-primitive-validation.sh --output-dir "$bag_mode_smoke_dir/baseline" --case-id validate-smoke >/dev/null
before_mtime="$(stat -f %m "$bag_mode_smoke_dir/baseline/before/metadata.txt")"

for required_file in validation-config.txt manual-result.md README.txt before/metadata.txt; do
    if [[ ! -f "$bag_mode_smoke_dir/baseline/$required_file" ]]; then
        echo "Bag Mode primitive harness did not write expected file: $required_file" >&2
        exit 1
    fi
done

if ! grep -q '^metadataRedacted=true$' "$bag_mode_smoke_dir/baseline/validation-config.txt"; then
    echo "Bag Mode primitive harness did not record redacted metadata mode" >&2
    exit 1
fi
if grep -q '^host=' "$bag_mode_smoke_dir/baseline/before/metadata.txt" &&
   ! grep -q '^host=<redacted>$' "$bag_mode_smoke_dir/baseline/before/metadata.txt"; then
    echo "Bag Mode primitive harness did not redact host metadata" >&2
    exit 1
fi
if scripts/bag-mode-primitive-validation.sh --output-dir "$bag_mode_smoke_dir/baseline" --case-id validate-smoke >/dev/null 2>"$bag_mode_smoke_error"; then
    echo "Bag Mode primitive harness overwrote a non-empty evidence directory without --continue" >&2
    exit 1
fi
if ! grep -q 'Output directory is not empty' "$bag_mode_smoke_error"; then
    cat "$bag_mode_smoke_error" >&2
    exit 1
fi
scripts/bag-mode-primitive-validation.sh --output-dir "$bag_mode_smoke_dir/baseline" --case-id validate-smoke --continue >/dev/null
after_mtime="$(stat -f %m "$bag_mode_smoke_dir/baseline/before/metadata.txt")"
if [[ "$before_mtime" != "$after_mtime" ]]; then
    echo "Bag Mode primitive harness rewrote the original before snapshot during --continue" >&2
    exit 1
fi

echo "==> swift test discovery"
test_list_output="$(mktemp)"
test_list_error="$(mktemp)"

if swift test list >"$test_list_output" 2>"$test_list_error"; then
    missing_targets=()
    for target in ClawShellCoreTests ClawShellContractTests; do
        if ! grep -q "$target" "$test_list_output"; then
            missing_targets+=("$target")
        fi
    done

    if [[ "${#missing_targets[@]}" -gt 0 ]]; then
        echo "swift test list succeeded but missed required test target(s): ${missing_targets[*]}" >&2
        cat "$test_list_output" >&2
        exit 1
    fi

    echo "==> swift test"
    swift test
else
    if grep -q 'This toolchain does not provide Testing or XCTest' "$test_list_error"; then
        echo "==> swift test skipped: this toolchain does not provide Testing or XCTest"
    else
        cat "$test_list_error" >&2
        exit 1
    fi
fi
