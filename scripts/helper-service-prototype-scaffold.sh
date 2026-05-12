#!/usr/bin/env bash
if [[ -z "${BASH_VERSION:-}" ]]; then
    echo "This script requires bash. Run it as: bash scripts/helper-service-prototype-scaffold.sh ..." >&2
    exit 2
fi
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: scripts/helper-service-prototype-scaffold.sh --output-dir DIR
   or: scripts/helper-service-prototype-scaffold.sh DIR

Creates a non-mutating starter directory for the #27 signed SMAppService helper
prototype evidence package. The generated manifest intentionally contains TODO
rows and no validation-config.txt/manual-result.md so it cannot pass the
prototype verifier until real signed-helper evidence is captured.
USAGE
}

OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            if [[ $# -lt 2 ]]; then
                echo "--output-dir requires a value" >&2
                exit 64
            fi
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 64
            ;;
        *)
            if [[ -n "$OUTPUT_DIR" ]]; then
                echo "Output directory provided more than once" >&2
                usage >&2
                exit 64
            fi
            OUTPUT_DIR="$1"
            shift
            ;;
    esac
done

if [[ -z "$OUTPUT_DIR" ]]; then
    usage >&2
    exit 64
fi

if [[ -e "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
    echo "Output path exists but is not a directory: $OUTPUT_DIR" >&2
    exit 73
fi

if [[ -e "$OUTPUT_DIR" ]]; then
    if [[ -n "$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
        echo "Output directory is not empty: $OUTPUT_DIR" >&2
        exit 73
    fi
fi

mkdir -p "$OUTPUT_DIR/evidence"

write_required_row() {
    local check_id="$1"
    printf '%s\tTODO\t\tReplace TODO with evidence and a captured relative evidence path before verification\n' "$check_id"
}

cat >"$OUTPUT_DIR/prototype-manifest.tsv" <<'EOF'
checkId	status	evidencePath	note
EOF

{
    write_required_row "app-bundle-layout"
    write_required_row "launchdaemon-plist"
    write_required_row "app-codesign"
    write_required_row "helper-codesign"
    write_required_row "app-designated-requirement"
    write_required_row "helper-designated-requirement"
    write_required_row "spctl-assessment"
    write_required_row "smappservice-register"
    write_required_row "smappservice-status-requires-approval"
    write_required_row "system-settings-approval"
    write_required_row "smappservice-status-enabled"
    write_required_row "helper-bootstrap-after-approval"
    write_required_row "post-reboot-helper-bootstrap"
    write_required_row "helper-update-old-inactive"
    write_required_row "helper-update-ledger-compatibility"
    write_required_row "helper-uninstall-unregister"
    write_required_row "helper-uninstall-state-cleanup"
    write_required_row "failure-unsigned-caller"
    write_required_row "failure-wrong-bundle-id-or-label"
    write_required_row "failure-wrong-user"
    write_required_row "failure-stale-app-version"
    write_required_row "failure-denied-or-revoked-approval"
    write_required_row "launchctl-status"
    write_required_row "log-evidence"
    printf '%s\tn/a\t\tNo package installer path used in this prototype package yet\n' "package-installer-signing"
    printf '%s\tn/a\t\tNo Homebrew cask path used in this prototype package yet\n' "homebrew-cask-semantics"
} >>"$OUTPUT_DIR/prototype-manifest.tsv"

cat >"$OUTPUT_DIR/README.md" <<'EOF'
# Helper Service Prototype Scaffold

This directory is a starter scaffold for issue #27. It is not evidence.

The manifest intentionally starts with `TODO` statuses for required checks and
does not create `validation-config.txt` or `manual-result.md`. Before attaching
a prototype package to #27, replace every required row with `status=evidence`
and a relative captured evidence path, then add filled `validation-config.txt`
and `manual-result.md` files from the real signed-helper prototype.

Run the verifier before attaching the package:

```sh
scripts/helper-service-prototype-verify.sh --manifest <this-dir>/prototype-manifest.tsv
```

Verifier success only means the evidence package is structurally complete. It
does not install, approve, run, or prove a helper.

Current local prerequisite gate:

```sh
scripts/helper-service-readiness.sh --output-dir .build/helper-service-readiness/local-$(date -u +%Y%m%dT%H%M%SZ)
```

The signed prototype still requires Developer ID Application signing for the
app/helper, Developer ID Installer signing when a package installer is used,
SMAppService registration/status evidence, admin approval evidence, reboot,
update, uninstall, failure-case, launchctl, and log evidence.
EOF

cat >"$OUTPUT_DIR/scaffold-config.txt" <<EOF
scaffoldFormat=smappservice-prototype-scaffold-v1
createdAtUtc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
metadataRedacted=true
manifest=prototype-manifest.tsv
verifier=scripts/helper-service-prototype-verify.sh --manifest $OUTPUT_DIR/prototype-manifest.tsv
EOF

echo "Helper service prototype scaffold written to $OUTPUT_DIR"
