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
temperature_validation_before=""
trap '[[ -n "$test_list_output" ]] && rm -f "$test_list_output"; [[ -n "$test_list_error" ]] && rm -f "$test_list_error"; [[ -n "$temperature_validation_before" ]] && rm -f "$temperature_validation_before"; rm -f "$bag_mode_smoke_error"; rm -rf "$bag_mode_smoke_dir"' EXIT

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

echo "==> temperature provider harness smoke"
temperature_smoke_dir="$bag_mode_smoke_dir/temperature-provider"
scripts/temperature-provider-validation.sh --output-dir "$temperature_smoke_dir" >/dev/null
for required_file in \
    metadata.txt \
    processinfo-thermal-state.txt \
    processinfo-thermal-state.status \
    pmset-therm.txt \
    pmset-therm.status \
    powermetrics-thermal.txt \
    powermetrics-thermal.status \
    battery-temperature.txt \
    battery-temperature.status \
    validation-config.txt \
    summary-computed.md \
    summary.md
do
    if [[ ! -f "$temperature_smoke_dir/$required_file" ]]; then
        echo "Temperature provider harness did not write expected file: $required_file" >&2
        exit 1
    fi
done
if ! grep -q '^bagModeTemperatureProviderReady=false$' "$temperature_smoke_dir/validation-config.txt"; then
    echo "Temperature provider harness should not mark Bag Mode temperature provider ready" >&2
    exit 1
fi
if ! grep -q '^candidateSelected=none$' "$temperature_smoke_dir/validation-config.txt"; then
    echo "Temperature provider harness should keep provider selection explicit" >&2
    exit 1
fi
if ! grep -q '^metadataRedacted=true$' "$temperature_smoke_dir/metadata.txt"; then
    echo "Temperature provider harness did not record redacted metadata mode" >&2
    exit 1
fi
if grep -Eq '^(host|user)=' "$temperature_smoke_dir/metadata.txt"; then
    echo "Temperature provider harness wrote host/user metadata" >&2
    exit 1
fi

temperature_validation_before="$(mktemp)"
cp "$temperature_smoke_dir/validation-config.txt" "$temperature_validation_before"
scripts/temperature-provider-validation.sh --output-dir "$temperature_smoke_dir" --continue >/dev/null
if ! cmp -s "$temperature_validation_before" "$temperature_smoke_dir/validation-config.txt"; then
    echo "Temperature provider harness rewrote validation config during --continue" >&2
    exit 1
fi

if scripts/temperature-provider-validation.sh --output-dir "$temperature_smoke_dir" >/dev/null 2>"$bag_mode_smoke_error"; then
    echo "Temperature provider harness overwrote a non-empty evidence directory without --continue" >&2
    exit 1
fi
if ! grep -q 'Output directory is not empty' "$bag_mode_smoke_error"; then
    cat "$bag_mode_smoke_error" >&2
    exit 1
fi

temperature_file_output="$bag_mode_smoke_dir/temperature-output-file"
touch "$temperature_file_output"
if scripts/temperature-provider-validation.sh --output-dir "$temperature_file_output" >/dev/null 2>"$bag_mode_smoke_error"; then
    echo "Temperature provider harness accepted an output path that is not a directory" >&2
    exit 1
fi
if ! grep -q 'not a directory' "$bag_mode_smoke_error"; then
    cat "$bag_mode_smoke_error" >&2
    exit 1
fi

temperature_bad_env_dir="$bag_mode_smoke_dir/temperature-bad-env"
if CLAWSHELL_TEMPERATURE_PROVIDER_TIMEOUT_SECONDS=abc \
    scripts/temperature-provider-validation.sh --output-dir "$temperature_bad_env_dir" >/dev/null 2>"$bag_mode_smoke_error"; then
    echo "Temperature provider harness accepted an invalid timeout value" >&2
    exit 1
fi
if [[ -e "$temperature_bad_env_dir" ]]; then
    echo "Temperature provider harness created evidence for an invalid timeout value" >&2
    exit 1
fi

temperature_fake_bin="$bag_mode_smoke_dir/temperature-fakes"
mkdir -p "$temperature_fake_bin"
cat >"$temperature_fake_bin/swift" <<'EOF'
#!/usr/bin/env bash
echo "thermalState=fair"
EOF
cat >"$temperature_fake_bin/pmset" <<'EOF'
#!/usr/bin/env bash
echo "CPU die temperature: 42 C"
EOF
cat >"$temperature_fake_bin/powermetrics" <<'EOF'
#!/usr/bin/env bash
echo "thermal sampler available"
EOF
cat >"$temperature_fake_bin/ioreg" <<'EOF'
#!/usr/bin/env bash
now="$(date +%s)"
cat <<EOT
      "UpdateTime" = $now
      "Temperature" = 3046
      "VirtualTemperature" = 3139
EOT
EOF
chmod +x "$temperature_fake_bin/swift" "$temperature_fake_bin/pmset" "$temperature_fake_bin/powermetrics" "$temperature_fake_bin/ioreg"

temperature_fake_dir="$bag_mode_smoke_dir/temperature-fake"
CLAWSHELL_TEMPERATURE_PROVIDER_TIMEOUT_SECONDS=5 \
CLAWSHELL_TEMPERATURE_PROVIDER_PROCESSINFO_TIMEOUT_SECONDS=5 \
PATH="$temperature_fake_bin:$PATH" scripts/temperature-provider-validation.sh --output-dir "$temperature_fake_dir" >/dev/null
if ! grep -q '^processInfoThermalState=fair$' "$temperature_fake_dir/validation-config.txt"; then
    echo "Temperature provider harness did not parse fake ProcessInfo output" >&2
    exit 1
fi
if ! grep -q '^pmsetCurrentNumericTemperature=true$' "$temperature_fake_dir/validation-config.txt"; then
    echo "Temperature provider harness did not parse fake pmset numeric output" >&2
    exit 1
fi
if ! grep -q '^powermetricsPermissionState=availableWithoutRoot$' "$temperature_fake_dir/validation-config.txt"; then
    echo "Temperature provider harness did not classify fake powermetrics success" >&2
    exit 1
fi
if ! grep -q '^batteryFreshWithin10Seconds=true$' "$temperature_fake_dir/validation-config.txt"; then
    echo "Temperature provider harness did not parse fake battery freshness" >&2
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
