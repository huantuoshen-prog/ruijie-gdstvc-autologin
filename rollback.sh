#!/bin/sh
set -eu
TARGET=/etc/ruijie
ROLLBACK="${TARGET}.rollback"
ROLLBACK_META="${ROLLBACK}.state"
PREVIOUS_INIT="${ROLLBACK}.init"
[ -d "$ROLLBACK" ] || { printf '%s\n' 'no rollback release is available' >&2; exit 1; }
enabled=false
running=false
[ -f "$ROLLBACK_META" ] && . "$ROLLBACK_META"
[ -x /etc/init.d/ruijie ] && /etc/init.d/ruijie stop || true
FAILED="${TARGET}.failed.$(date +%s)"
mv "$TARGET" "$FAILED"
mv "$ROLLBACK" "$TARGET"
if [ -f "$TARGET/init.d/ruijie" ]; then
    cp "$TARGET/init.d/ruijie" /etc/init.d/ruijie
elif [ -f "$PREVIOUS_INIT" ]; then
    cp "$PREVIOUS_INIT" /etc/init.d/ruijie
else
    rm -f /etc/init.d/ruijie
fi
[ -x /etc/init.d/ruijie ] || { printf '%s\n' "rollback restored files but no service script; failed files kept at $FAILED" >&2; exit 1; }
[ "$enabled" = true ] && /etc/init.d/ruijie enable || /etc/init.d/ruijie disable
[ "$running" = true ] && /etc/init.d/ruijie start
"$TARGET/ruijiectl" runtime >/dev/null || { printf '%s\n' "rollback health check failed; failed files kept at $FAILED" >&2; exit 1; }
printf '%s\n' "rollback complete; failed files kept at $FAILED"
