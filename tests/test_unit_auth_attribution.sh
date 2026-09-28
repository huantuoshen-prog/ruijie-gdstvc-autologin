#!/bin/bash
# Run the real daemon loop against isolated state and synthetic login outcomes.
set -e
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
. "$PROJECT_DIR/lib/common.sh"
. "$PROJECT_DIR/lib/daemon.sh"
CONFIG_DIR="$test_dir/config"
PIDFILE="$test_dir/daemon.pid"
LOGFILE="$test_dir/daemon.log"
_DAEMON_STATE_FILE="$test_dir/state"
_DAEMON_BACKOFF_FILE="$test_dir/backoff"
mkdir -p "$CONFIG_DIR"
is_configured() { return 0; }
load_config() { USERNAME=test; PASSWORD=test; ACCOUNT_TYPE=student; }
_daemon_health_refresh_snapshots() { :; }
_daemon_health_event() { :; }
_daemon_health_collect_baseline_if_due() { :; }
check_network() { NETWORK_CHECK_RESULT=offline; return 1; }
sleep() { :; }
do_login() {
    login_calls=$((login_calls + 1))
    LOGIN_RESULT_KIND=failed
    [ "$login_calls" -ge "$succeed_on" ] || return 1
    LOGIN_RESULT_KIND="$outcome"
    return 0
}
passed=0
for succeed_on in 1 2 6; do
    for outcome in authenticated already_online; do
        : > "$LOGFILE"
        rm -f "$CONFIG_DIR/auth-outcomes.log" "$CONFIG_DIR/last-auth-success"
        _reset_backoff
        login_calls=0
        DAEMON_TEST_MAX_LOOPS=$((succeed_on + 1))
        daemon_loop
        [ "$(cat "$_DAEMON_STATE_FILE")" = ONLINE ]
        [ "$(wc -l < "$CONFIG_DIR/auth-outcomes.log")" -eq 1 ]
        grep -q " $outcome$" "$CONFIG_DIR/auth-outcomes.log"
        if [ "$outcome" = authenticated ]; then
            [ -n "$(get_last_auth_time)" ]
            grep -q '认证成功' "$LOGFILE"
        else
            [ -z "$(get_last_auth_time || true)" ]
            grep -q '网络已恢复（未发起认证）' "$LOGFILE"
            ! grep -q '认证成功' "$LOGFILE"
        fi
        printf '[PASS] recovery attempt=%s outcome=%s\n' "$succeed_on" "$outcome"
        passed=$((passed + 1))
    done
done
check_network() { NETWORK_CHECK_RESULT=online; return 0; }
for outcome in authenticated already_online; do
    rm -f "$CONFIG_DIR/auth-outcomes.log" "$CONFIG_DIR/last-auth-success"
    succeed_on=1 login_calls=0 DAEMON_TEST_MAX_LOOPS=10
    daemon_loop
    if [ "$outcome" = authenticated ]; then
        [ -s "$CONFIG_DIR/last-auth-success" ]
    else
        [ ! -e "$CONFIG_DIR/auth-outcomes.log" ]
    fi
    printf '[PASS] periodic ensure outcome=%s\n' "$outcome"
    passed=$((passed + 1))
done
printf '%s passed, 0 failed\n' "$passed"
