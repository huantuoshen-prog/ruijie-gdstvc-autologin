#!/bin/bash
# Isolated configuration regression: no network/auth/service operations.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for tool in jq flock; do command -v "$tool" >/dev/null || exit 77; done
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
export CONFIG_DIR="$scratch" CONFIG_FILE="$scratch/account.conf"
ctl() { bash "$ROOT/ruijiectl" "$@"; }
payload='{"revision":"0","username":"test-teacher","password":" p&a=ss+% 中文 ","account_type":"teacher","operator":"default","proxy_url":"http://127.0.0.1:7890","proxy_url_https":""}'
printf '%s' "$payload" | ctl config set > "$scratch/result"
jq -e '.success and .data.account_type == "teacher"' "$scratch/result" >/dev/null
grep -Fx 'PASSWORD= p&a=ss+% 中文 ' "$CONFIG_FILE" >/dev/null
before="$(sha256sum "$CONFIG_FILE")"
if printf '%s' "$payload" | ctl config set > "$scratch/result"; then echo 'stale revision accepted' >&2; exit 1; fi
jq -e '.code == "CONFLICT"' "$scratch/result" >/dev/null
[ "$before" = "$(sha256sum "$CONFIG_FILE")" ]
# Test the writer itself, ensuring the revision guard resides inside its lock.
. "$ROOT/lib/common.sh"
. "$ROOT/lib/config.sh"
rc=0
config_write x y student DianXin 300 '' '' '' 0 || rc=$?
[ "$rc" = 76 ]
[ "$before" = "$(sha256sum "$CONFIG_FILE")" ]
exec 7>"${CONFIG_FILE}.lock"
flock -x 7
rc=0
config_write x y student DianXin 300 '' '' '' "$(config_revision)" || rc=$?
[ "$rc" = 75 ]
exec 7>&-
# A failed temporary-file write must leave the committed file untouched and
# release the descriptor even when the caller enables errexit.
cat() { return 1; }
rc=0
config_write x y student DianXin 300 '' '' '' "$(config_revision)" || rc=$?
unset -f cat
[ "$rc" = 1 ]
[ "$before" = "$(sha256sum "$CONFIG_FILE")" ]
# Reading a saved password must preserve literal backslashes and equals signs.
literal='  p\\a\n\t=中文  '
config_write test "$literal" student DianXin 300 '' '' '' "$(config_revision)"
load_config
[ "$PASSWORD" = "$literal" ]
printf '%s\n' 'PASS: special password, teacher operator, stale revision, writer conflict, lock contention, failed write, literal config read'
