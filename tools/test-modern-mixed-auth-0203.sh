#!/bin/sh
# Regression of Mixed Proxy credential edits against isolated mock UCI.
set -eu
cd "$(dirname "$0")/.."
src=podkop_bot.sh
[ "$#" -eq 0 ] || src="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sed -n '/^_m3_section_extra() {/,/^}/p' "$src" > "$tmp/function.sh"
cat > "$tmp/test.sh" <<'MOCK'
#!/bin/sh
set -eu
. "$1"
PODKOP_UCI=podkop
PODKOP_VARIANT=podkop-exp
STATE_FILE="$2/state"
LAST_MENU_MSG_FILE="$2/last"
CALLBACK_MSG_ID=99
E_ERR=ERR
E_WARN=WARN
E_OK=OK
printf '42\n' > "$LAST_MENU_MSG_FILE"
get_active_section() { echo rule0; }
_podkop_exp_v2() { return 0; }
uci() {
    [ "$1" = -q ] && shift
    [ "$1" = get ] || return 1
    case "$2" in podkop.rule0) echo section ;; *) return 1 ;; esac
}
delete_message() { :; }
send_message() { printf '%s\n' "$1" >> "$2" 2>/dev/null || printf '%s\n' "$1" >> "$log"; }
_m3_settings_ui() { :; }
_fk_stage_set() { printf '%s=%s\n' "$1" "$2" >> "$changes"; }
_fk_stage_delete() { printf 'DELETE %s\n' "$1" >> "$changes"; }
_fk_txn_commit_reload() { return 0; }
_fk_txn_fail_msg() { echo ERROR; }
log="$2/log"; changes="$2/changes"
printf 'wait_m3_auth_password\nrule0\n' > "$STATE_FILE"
_m3_section_extra STATE_INPUT 42 'P@ss:w0rd' wait_m3_auth_password
grep -Fqx 'podkop.rule0.mixed_proxy_password=P@ss:w0rd' "$changes"
! grep -Fq 'P@ss:w0rd' "$log"
printf 'wait_m3_auth_username\nrule0\n' > "$STATE_FILE"
_m3_section_extra STATE_INPUT 42 'user1' wait_m3_auth_username
grep -Fqx 'podkop.rule0.mixed_proxy_username=user1' "$changes"
printf 'wait_m3_auth_username\nrule0\n' > "$STATE_FILE"
_m3_section_extra STATE_INPUT 42 'bad user' wait_m3_auth_username
[ "$(grep -c '^podkop.rule0.mixed_proxy_username=' "$changes")" = 1 ]
printf 'wait_m3_auth_password\nother_rule\n' > "$STATE_FILE"
_m3_section_extra STATE_INPUT 42 'wrongsection' wait_m3_auth_password
! grep -Fq 'wrongsection' "$changes"
echo 'PASS: masked credentials, guarded input and section identity'
MOCK
sh -n "$tmp/function.sh"
sh "$tmp/test.sh" "$tmp/function.sh" "$tmp"
