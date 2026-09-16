#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

. "$PROJECT_DIR/lib/common.sh"
. "$PROJECT_DIR/lib/daemon.sh"

LOGFILE="$SCRATCH/daemon.log"
DAEMON_LOG_ROTATE_BYTES=32
printf '%040d' 0 > "$LOGFILE"
_log_daemon "rotation-check"

[ -f "${LOGFILE}.1" ]
grep -q rotation-check "$LOGFILE"
printf '%s\n' 'PASS: daemon log rotates before appending new entries'
