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

echo "==> swift test discovery"
test_list_output="$(mktemp)"
test_list_error="$(mktemp)"
trap 'rm -f "$test_list_output" "$test_list_error"' EXIT

if swift test list >"$test_list_output" 2>"$test_list_error"; then
    if grep -Eq 'ClawShell(Core|Contract)Tests' "$test_list_output"; then
        echo "==> swift test"
        swift test
    else
        echo "swift test list succeeded but discovered no ClawShell tests" >&2
        cat "$test_list_output" >&2
        exit 1
    fi
else
    if grep -q 'This toolchain does not provide Testing or XCTest' "$test_list_error"; then
        echo "==> swift test skipped: this toolchain does not provide Testing or XCTest"
    else
        cat "$test_list_error" >&2
        exit 1
    fi
fi
