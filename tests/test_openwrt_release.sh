#!/bin/ash
# Runs inside an official OpenWrt rootfs container. It never calls auth or
# starts the daemon; the tested service state remains disabled and stopped.
set -eu
ARCHIVE="${1:?core release archive required}"
work="$(mktemp -d)"
trap 'rm -rf "$work"; rm -f /var/run/ruijie-daemon.pid' EXIT

extract_release() {
    directory="$1"
    mkdir -p "$directory"
    tar -xzf "$ARCHIVE" -C "$directory"
}

extract_release "$work/fresh"
"$work/fresh/ruijie-core/install.sh"
[ -x /etc/ruijie/ruijiectl ]
/etc/ruijie/ruijiectl runtime | jq -e '.success and .schema_version == 2' >/dev/null
! /etc/init.d/ruijie enabled >/dev/null 2>&1
[ ! -f /var/run/ruijie-daemon.pid ]

# A stopped installation must remain stopped during an upgrade and rollback.
printf '%s\n' before-upgrade > /etc/ruijie/preserved-marker
extract_release "$work/upgrade"
"$work/upgrade/ruijie-core/install.sh"
[ -f /etc/ruijie.rollback/preserved-marker ]
! /etc/init.d/ruijie enabled >/dev/null 2>&1
[ ! -f /var/run/ruijie-daemon.pid ]
/etc/ruijie/rollback.sh
[ -f /etc/ruijie/preserved-marker ]
! /etc/init.d/ruijie enabled >/dev/null 2>&1

# A post-switch health failure must put back the complete previous release.
printf '%s\n' before-failed-upgrade > /etc/ruijie/failure-marker
extract_release "$work/bad"
printf '%s\n' '#!/bin/bash' 'exit 9' > "$work/bad/ruijie-core/ruijiectl"
chmod 700 "$work/bad/ruijie-core/ruijiectl"
(cd "$work/bad/ruijie-core" && find . -type f ! -name manifest.sha256 | sort | xargs sha256sum > manifest.sha256)
if "$work/bad/ruijie-core/install.sh"; then
    printf '%s\n' 'bad release unexpectedly installed' >&2
    exit 1
fi
[ -f /etc/ruijie/failure-marker ]
/etc/ruijie/ruijiectl runtime | jq -e '.success' >/dev/null
! /etc/init.d/ruijie enabled >/dev/null 2>&1

# A checksum failure and an unknown active process must fail before switching.
extract_release "$work/corrupt"
printf '%s\n' altered >> "$work/corrupt/ruijie-core/lib/common.sh"
if "$work/corrupt/ruijie-core/install.sh"; then
    printf '%s\n' 'corrupt release unexpectedly installed' >&2
    exit 1
fi
[ -f /etc/ruijie/failure-marker ]
sleep 30 & unknown_pid=$!
printf '%s\n' "$unknown_pid" > /var/run/ruijie-daemon.pid
extract_release "$work/legacy"
if "$work/legacy/ruijie-core/install.sh"; then
    printf '%s\n' 'unknown legacy process unexpectedly replaced' >&2
    exit 1
fi
kill "$unknown_pid" 2>/dev/null || true
rm -f /var/run/ruijie-daemon.pid
[ -f /etc/ruijie/failure-marker ]
printf '%s\n' 'PASS: fresh install, stopped upgrade, rollback, health failure, checksum failure, unknown daemon guard'
