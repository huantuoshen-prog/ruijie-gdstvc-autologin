#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/bin" "$SCRATCH/config"
cat > "$SCRATCH/bin/curl" <<'EOF'
#!/bin/sh
printf '%s' "${FAKE_HTTP_CODE:-000}"
EOF
chmod 755 "$SCRATCH/bin/curl"
cat > "$SCRATCH/bin/flock" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 755 "$SCRATCH/bin/flock"

run_status() {
    FAKE_HTTP_CODE="$1" RUIJIE_CONFIG_HOME="$SCRATCH/config" PATH="$SCRATCH/bin:$PATH" \
        "$PROJECT_DIR/ruijiectl" status
}

unknown="$(run_status 000)"
jq -e '.success and .data.online == null and .data.connectivity == "unknown"' >/dev/null <<<"$unknown"

offline="$(run_status 302)"
jq -e '.success and .data.online == false and .data.connectivity == "offline"' >/dev/null <<<"$offline"

online="$(run_status 204)"
jq -e '.success and .data.online == true and .data.connectivity == "online"' >/dev/null <<<"$online"

printf '%s\n' 'PASS: status preserves online, offline and unknown connectivity states'
