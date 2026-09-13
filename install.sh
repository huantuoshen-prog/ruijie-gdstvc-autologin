#!/bin/sh
# Install a verified, self-contained core release on OpenWrt.
set -eu

SOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET=/etc/ruijie
STAGE="${TARGET}.next.$$"
ROLLBACK="${TARGET}.rollback"
PREVIOUS_INIT="${ROLLBACK}.init"
MANIFEST="$SOURCE_DIR/manifest.sha256"

fail() { printf '%s\n' "install failed: $*" >&2; exit 1; }
[ -f /etc/openwrt_release ] || command -v ubus >/dev/null 2>&1 || fail 'OpenWrt/procd is required'
for command in bash curl jq flock sha256sum tar; do command -v "$command" >/dev/null 2>&1 || fail "missing dependency: $command"; done
[ -f "$MANIFEST" ] || fail 'manifest.sha256 is missing; use an official release bundle'

# A legacy background loop can still be authenticating.  Replacing its files
# while it is live cannot prove that the connection will remain uninterrupted,
# so never migrate over it automatically.
if [ -f /var/run/ruijie-daemon.pid ]; then
    legacy_pid="$(cat /var/run/ruijie-daemon.pid 2>/dev/null || true)"
    if [ -n "$legacy_pid" ] && kill -0 "$legacy_pid" 2>/dev/null; then
        fail "legacy daemon is running (PID $legacy_pid); installation was not started and no network action was taken"
    fi
fi
(grep -q 'ruijie-auto-login' /etc/rc.local 2>/dev/null || grep -q 'ruijie-auto-login' /etc/crontabs/root 2>/dev/null) \
    && fail 'legacy rc.local/cron startup entries detected; migrate them in a planned maintenance step before installing'

(cd "$SOURCE_DIR" && sha256sum -c manifest.sha256) || fail 'release checksum verification failed'
rm -rf "$STAGE"
mkdir -p "$STAGE/lib" "$STAGE/init.d"
for file in ruijie.sh ruijie_student.sh ruijie_teacher.sh ruijiectl uninstall.sh rollback.sh; do
    [ -f "$SOURCE_DIR/$file" ] && cp "$SOURCE_DIR/$file" "$STAGE/$file"
done
cp "$SOURCE_DIR"/lib/*.sh "$STAGE/lib/"
cp "$SOURCE_DIR/init.d/ruijie" "$STAGE/init.d/ruijie"
chmod 700 "$STAGE"/ruijiectl "$STAGE"/rollback.sh
chmod 755 "$STAGE"/ruijie.sh "$STAGE"/ruijie_student.sh "$STAGE"/ruijie_teacher.sh "$STAGE"/uninstall.sh "$STAGE"/init.d/ruijie "$STAGE"/lib/*.sh

was_running=false
[ -x /etc/init.d/ruijie ] && /etc/init.d/ruijie running >/dev/null 2>&1 && was_running=true
[ -d "$TARGET" ] && {
    rm -rf "$ROLLBACK" "$PREVIOUS_INIT"
    mv "$TARGET" "$ROLLBACK"
    [ -f /etc/init.d/ruijie ] && cp -p /etc/init.d/ruijie "$PREVIOUS_INIT" || true
}
mv "$STAGE" "$TARGET"
cp "$TARGET/init.d/ruijie" /etc/init.d/ruijie
/etc/init.d/ruijie enable
if [ "$was_running" = true ]; then /etc/init.d/ruijie restart; fi
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
        [ "$was_running" = true ] && /etc/init.d/ruijie start || true
    }
    fail 'post-install health check failed; previous release restored'
}
printf '%s\n' 'installed; previous complete release is available through /etc/ruijie/rollback.sh'
