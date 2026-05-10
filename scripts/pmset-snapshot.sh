#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-"$ROOT_DIR/.build/power-snapshots/$(date -u +%Y%m%dT%H%M%SZ)"}"

mkdir -p "$OUTPUT_DIR"

capture() {
    local name="$1"
    shift

    {
        echo "$ $*"
        "$@"
    } >"$OUTPUT_DIR/$name.txt" 2>&1 || {
        local status=$?
        echo "command exited with status $status" >>"$OUTPUT_DIR/$name.txt"
    }
}

{
    echo "capturedAtUTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "host=$(hostname)"
    echo "user=$(id -un)"
} >"$OUTPUT_DIR/metadata.txt"

capture "sw_vers" sw_vers
capture "uname" uname -a
capture "pmset-assertions" pmset -g assertions
capture "pmset-custom" pmset -g custom
capture "pmset-battery" pmset -g batt
capture "pmset-live" pmset -g live

if command -v ioreg >/dev/null 2>&1; then
    capture "ioreg-power" ioreg -r -c IOPMPowerSource -a
fi

echo "Power snapshot written to $OUTPUT_DIR"
