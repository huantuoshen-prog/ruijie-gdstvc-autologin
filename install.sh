#!/bin/sh
# Install a verified, self-contained core release on OpenWrt.
set -eu

SOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET=/etc/ruijie
STAGE="${TARGET}.next.$$"
ROLLBACK="${TARGET}.rollback"
PREVIOUS_INIT="${ROLLBACK}.init"
ROLLBACK_META="${ROLLBACK}.state"
MANIFEST="$SOURCE_DIR/manifest.sha256"

fail() { printf '%s\n' "install failed: $*" >&2; exit 1; }
[ -f /etc/openwrt_release ] || command -v ubus >/dev/null 2>&1 || fail 'OpenWrt/procd is required'
for command in bash curl jq flock sha256sum tar; do command -v "$command" >/dev/null 2>&1 || fail "missing dependency: $command"; done
[ -f "$MANIFEST" ] || fail 'manifest.sha256 is missing; use an official release bundle'

service_enabled=false
service_running=false
init_present=false
[ -f /etc/init.d/ruijie ] && init_present=true
[ -x /etc/init.d/ruijie ] && /etc/init.d/ruijie enabled >/dev/null 2>&1 && service_enabled=true
[ -x /etc/init.d/ruijie ] && /etc/init.d/ruijie running >/dev/null 2>&1 && service_running=true

# A legacy background loop can still be authenticating.  A daemon belonging to
# this release is stopped deliberately and restored afterwards; an unrecognised
# process is never killed by an installer.
if [ -f /var/run/ruijie-daemon.pid ]; then
    legacy_pid="$(cat /var/run/ruijie-daemon.pid 2>/dev/null || true)"
    if [ -n "$legacy_pid" ] && kill -0 "$legacy_pid" 2>/dev/null; then
        case "$(tr '\000' ' ' < "/proc/$legacy_pid/cmdline" 2>/dev/null || true)" in
            *"$TARGET/ruijiectl daemon-run"*) service_running=true ;;
            *) fail "unrecognised legacy daemon is running (PID $legacy_pid); installation was not started and no network action was taken" ;;
        esac
    fi
fi
(grep -q 'ruijie-auto-login' /etc/rc.local 2>/dev/null || grep -q 'ruijie-auto-login' /etc/crontabs/root 2>/dev/null) \
    && fail 'legacy rc.local/cron startup entries detected; migrate them in a planned maintenance step before installing'

(cd "$SOURCE_DIR" && sha256sum -c manifest.sha256) || fail 'release checksum verification failed'
rm -rf "$STAGE"
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM
mkdir -p "$STAGE/lib" "$STAGE/init.d"
for file in ruijie.sh ruijie_student.sh ruijie_teacher.sh ruijiectl uninstall.sh rollback.sh; do
    [ -f "$SOURCE_DIR/$file" ] && cp "$SOURCE_DIR/$file" "$STAGE/$file"
done
cp "$SOURCE_DIR"/lib/*.sh "$STAGE/lib/"
cp "$SOURCE_DIR/init.d/ruijie" "$STAGE/init.d/ruijie"
chmod 700 "$STAGE"/ruijiectl "$STAGE"/rollback.sh
chmod 755 "$STAGE"/ruijie.sh "$STAGE"/ruijie_student.sh "$STAGE"/ruijie_teacher.sh "$STAGE"/uninstall.sh "$STAGE"/init.d/ruijie "$STAGE"/lib/*.sh

if [ "$service_running" = true ]; then
    /etc/init.d/ruijie stop || fail 'could not stop the existing service'
    attempts=0
    while [ "$attempts" -lt 10 ] && [ -f /var/run/ruijie-daemon.pid ]; do
        pid="$(cat /var/run/ruijie-daemon.pid 2>/dev/null || true)"
        [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null && break
        sleep 1
        attempts=$((attempts + 1))
    done
    [ "$attempts" -lt 10 ] || fail 'existing service did not stop; installation was cancelled before files changed'
fi
[ -d "$TARGET" ] && {
    rm -rf "$ROLLBACK" "$PREVIOUS_INIT" "$ROLLBACK_META"
    mv "$TARGET" "$ROLLBACK"
    [ -f /etc/init.d/ruijie ] && cp -p /etc/init.d/ruijie "$PREVIOUS_INIT" || true
    printf 'enabled=%s\nrunning=%s\ninit_present=%s\n' "$service_enabled" "$service_running" "$init_present" > "$ROLLBACK_META"
}
mv "$STAGE" "$TARGET"
trap - EXIT HUP INT TERM
cp "$TARGET/init.d/ruijie" /etc/init.d/ruijie
[ "$service_enabled" = true ] && /etc/init.d/ruijie enable || /etc/init.d/ruijie disable
[ "$service_running" = true ] && /etc/init.d/ruijie start
"$TARGET/ruijiectl" runtime >/dev/null || {
    [ -d "$ROLLBACK" ] && {
        /etc/init.d/ruijie stop 2>/dev/null || true
        rm -rf "$TARGET"
        mv "$ROLLBACK" "$TARGET"
        if [ -f "$PREVIOUS_INIT" ]; then
            cp "$PREVIOUS_INIT" /etc/init.d/ruijie
        else
            rm -f /etc/init.d/ruijie
        fi
        if [ -f "$ROLLBACK_META" ]; then . "$ROLLBACK_META"; fi
        [ "${enabled:-false}" = true ] && /etc/init.d/ruijie enable || /etc/init.d/ruijie disable || true
        [ "${running:-false}" = true ] && /etc/init.d/ruijie start || true
    }
    fail 'post-install health check failed; previous release restored'
}
printf '%s\n' 'installed; previous release state is available through /etc/ruijie/rollback.sh'
