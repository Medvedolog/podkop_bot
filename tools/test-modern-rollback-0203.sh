#!/bin/sh
# Mock UCI transactions and service recovery; no OpenWrt config touched.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p /tmp/podkop_bot
sed -n '/^_fk_txn_commit_reload() {/,/^}/p' podkop_bot.sh > "$tmp/transaction.sh"
[ -s "$tmp/transaction.sh" ]
sh -n "$tmp/transaction.sh"
. "$tmp/transaction.sh"
PODKOP_UCI=forkop
TMP_CONFIG="$tmp/forkop"
logger() { :; }
cp() {
    if [ "$1" = '/etc/config/forkop' ]; then
        [ "${FAIL_SNAPSHOT:-0}" = 0 ] || return 1
        command cp "$TMP_CONFIG" "$2"
    elif [ "$2" = '/etc/config/forkop' ]; then
        command cp "$1" "$TMP_CONFIG"
    else command cp "$@"; fi
}
uci() {
    [ "$1" = -q ] && shift
    case "$1" in
        revert) return 0 ;;
        commit) [ "${FAIL_RECOVERY_COMMIT:-0}" = 0 ] ;;
        *) return 1 ;;
    esac
}
uci_commit_safe() {
    [ "${FAIL_PRIMARY_COMMIT:-0}" = 0 ] || return 1
    printf 'modified\n' > "$TMP_CONFIG"
}
safe_reload_podkop() {
    RELOAD_COUNT=$((RELOAD_COUNT+1))
    [ "$RELOAD_COUNT" -eq 1 ] && [ "${FAIL_INITIAL_RELOAD:-0}" = 1 ] && return 1
    [ "$RELOAD_COUNT" -gt 1 ] && [ "${FAIL_RECOVERY_RELOAD:-0}" = 1 ] && return 1
    return 0
}
case_run() {
    printf 'original\n' > "$TMP_CONFIG"
    RELOAD_COUNT=0
    result=0
    _fk_txn_commit_reload || result=$?
}
FAIL_INITIAL_RELOAD=0 FAIL_RECOVERY_RELOAD=0 FAIL_RECOVERY_COMMIT=0 FAIL_PRIMARY_COMMIT=0 FAIL_SNAPSHOT=0
case_run
[ "$result" = 0 ] && [ "$(cat "$TMP_CONFIG")" = modified ] && [ "$RELOAD_COUNT" -eq 1 ]
FAIL_INITIAL_RELOAD=1
case_run
[ "$result" = 2 ] && [ "$(cat "$TMP_CONFIG")" = original ] && [ "$RELOAD_COUNT" -eq 2 ]
FAIL_RECOVERY_RELOAD=1
case_run
[ "$result" = 4 ] && [ "$(cat "$TMP_CONFIG")" = original ] && [ "$RELOAD_COUNT" -eq 2 ]
FAIL_RECOVERY_RELOAD=0 FAIL_RECOVERY_COMMIT=1
case_run
[ "$result" = 4 ] && [ "$(cat "$TMP_CONFIG")" = original ] && [ "$RELOAD_COUNT" -eq 1 ]
FAIL_RECOVERY_COMMIT=0 FAIL_INITIAL_RELOAD=0 FAIL_PRIMARY_COMMIT=1
case_run
[ "$result" = 1 ] && [ "$(cat "$TMP_CONFIG")" = original ] && [ "$RELOAD_COUNT" -eq 0 ]
FAIL_PRIMARY_COMMIT=0 FAIL_SNAPSHOT=1
case_run
[ "$result" = 3 ] && [ "$(cat "$TMP_CONFIG")" = original ] && [ "$RELOAD_COUNT" -eq 0 ]
echo 'PASS rollback: success, revert, engine/commit recovery failure, commit and snapshot failure'
