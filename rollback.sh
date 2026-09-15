#!/bin/sh
set -eu
TARGET=/etc/ruijie
ROLLBACK="${TARGET}.rollback"
ROLLBACK_META="${ROLLBACK}.state"
[ -d "$ROLLBACK" ] || { printf '%s\n' 'no rollback release is available' >&2; exit 1; }
enabled=false
running=false
[ -f "$ROLLBACK_META" ] && . "$ROLLBACK_META"
[ -x /etc/init.d/ruijie ] && /etc/init.d/ruijie stop || true
FAILED="${TARGET}.failed.$(date +%s)"
mv "$TARGET" "$FAILED"
mv "$ROLLBACK" "$TARGET"
cp "$TARGET/init.d/ruijie" /etc/init.d/ruijie
[ "$enabled" = true ] && /etc/init.d/ruijie enable || /etc/init.d/ruijie disable
[ "$running" = true ] && /etc/init.d/ruijie start
"$TARGET/ruijiectl" runtime >/dev/null || { printf '%s\n' "rollback health check failed; failed files kept at $FAILED" >&2; exit 1; }
printf '%s\n' "rollback complete; failed files kept at $FAILED"
