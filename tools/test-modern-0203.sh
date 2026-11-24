#!/bin/sh
# Native 0.20.3 rule editors against fake UCI; never mutate a router.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sed -n '/^# --- 0.20.3: Modern/,/^# --- end 0.20.3 editing primitives ---/p' podkop_bot.sh > "$tmp/modern.sh"
[ -s "$tmp/modern.sh" ]
sh -n podkop_bot.sh
sh -n "$tmp/modern.sh"
. "$tmp/modern.sh"

PODKOP_UCI=forkop
PODKOP_VARIANT=forkop
LOG="$tmp/uci.log"
: > "$LOG"
MODE=disabled
_forkop_v2() { [ "$PODKOP_VARIANT" = forkop ]; }
_podkop_exp_v2() { [ "$PODKOP_VARIANT" = experimental ]; }
_fk_valid_port() { case "$1" in 443|1000-2000) return 0 ;; *) return 1 ;; esac; }
validate_ip_or_cidr() {
    case "$1" in 192.0.2.10|192.0.2.0/24|198.51.100.2) return 0 ;; *) return 1 ;; esac
}
uci() {
    [ "$1" = -q ] && shift
    case "$1" in
        get)
            case "$2" in
                forkop.main|podkop.main) echo section ;;
                *.user_domain_list_type|*.user_subnet_list_type) echo "$MODE" ;;
                *) printf '\n' ;;
            esac ;;
        add_list) printf 'ADD:%s\n' "$2" >> "$LOG" ;;
        del_list) printf 'DEL:%s\n' "$2" >> "$LOG" ;;
        revert) printf 'REVERT:%s\n' "$2" >> "$LOG" ;;
        *) return 1 ;;
    esac
}
_fk_stage_set() { printf 'SET:%s=%s\n' "$1" "$2" >> "$LOG"; }
_fk_txn_commit_reload() { echo COMMIT >> "$LOG"; }

[ "$(_m3_field_kind destinations)" = text ]
[ "$(_m3_field_kind community_lists)" = list ]
if _m3_field_kind user_domains >/dev/null 2>&1; then exit 1; fi
_m3_apply_items add only_devices '192.0.2.10' main
grep -qx 'ADD:forkop.main.only_devices=192.0.2.10' "$LOG"
_m3_apply_items replace destinations 'example.org' main
grep -qx 'SET:forkop.main.destinations=example.org' "$LOG"
_m3_apply_items del ports 443 main
grep -qx 'DEL:forkop.main.ports=443' "$LOG"
cp "$LOG" "$tmp/prev"
if _m3_apply_items add only_devices '192.0.2.10
bad_host' main; then exit 1; fi
cmp "$LOG" "$tmp/prev"
if _m3_apply_items add not_a_field test main; then exit 1; fi
cmp "$LOG" "$tmp/prev"

PODKOP_VARIANT=experimental PODKOP_UCI=podkop
[ "$(_m3_field_kind user_domains)" = list ]
if _m3_field_kind destinations >/dev/null 2>&1; then exit 1; fi
_m3_apply_items add user_domains 'example.org' main
grep -qx 'SET:podkop.main.user_domain_list_type=dynamic' "$LOG"
grep -qx 'ADD:podkop.main.user_domains=example.org' "$LOG"
MODE=text
cp "$LOG" "$tmp/prev"
if _m3_apply_items add user_domains 'other.example' main; then exit 1; fi
cmp "$LOG" "$tmp/prev"
MODE=dynamic
_m3_apply_items del user_domains 'example.org' main
grep -qx 'DEL:podkop.main.user_domains=example.org' "$LOG"
if _m3_apply_items add mixed_proxy_password secret main; then exit 1; fi
echo "PASS modern 0.20.3 UCI field allowlists, list edits, no legacy overwrite"
# Exercise the callback UI with fake UCI; validate each generated keyboard JSON.
for fn in _m3_ui _m3_settings_ui _m3_section_extra _m3_bool_allowed; do
    awk -v fn="$fn" '$0 == fn"() {" {p=1} p{print} p && /^}$/ {exit}' podkop_bot.sh
done > "$tmp/ui.sh"
sh -n "$tmp/ui.sh"
. "$tmp/ui.sh"
STATE_FILE="$tmp/state"
LAST_MENU_MSG_FILE="$tmp/menu"
CALLBACK_MSG_ID=42
E_SET='[SET]' E_GLOB='[GLOB]' E_WARN='[WARN]' E_ERR='[ERR]' E_EDIT='[EDIT]' E_BACK='[BACK]'
echo 42 > "$LAST_MENU_MSG_FILE"
get_active_section() { echo main; }
html_escape() { printf '%s' "$1"; }
json_escape() { printf '%s' "$1"; }
_utf8_head() { printf '%s' "$1"; }
delete_message() { :; }
send_or_edit() { printf '%s\n' "$3" > "$tmp/keyboard.json"; }
send_message() { :; }
_fail() { echo "UI test failed: $*" >&2; exit 1; }
_keyboard() { jq -e "$1" "$tmp/keyboard.json" >/dev/null || _fail "$1"; }

set -x
PODKOP_VARIANT=forkop PODKOP_UCI=forkop
_m3_ui m3_main 42 '' ''
_keyboard '.inline_keyboard[0][0].callback_data=="m3_route"'
_m3_ui m3_route 42 '' ''
_keyboard '.inline_keyboard | length >= 8'
_m3_settings_ui m3_sec 42 '' ''
_keyboard '.inline_keyboard[1][0].callback_data=="m3_action"'
_m3_section_extra m3_action 42 '' ''
_keyboard '.inline_keyboard[0][0].callback_data=="m3_action_pick_connection"'
_m3_section_extra m3_action_pick_block 42 '' ''
_keyboard '.inline_keyboard[0][0].callback_data=="m3_action_set_block"'
_m3_section_extra m3_action_set_block 42 '' ''
grep -qx 'SET:forkop.main.action=block' "$LOG"
_m3_settings_ui m3_global 42 '' ''
_keyboard '.inline_keyboard | length >= 5'
_m3_settings_ui m3_sw_disable_quic 42 '' ''
_keyboard '.inline_keyboard[0][0].callback_data=="m3_apply_disable_quic_1"'
_m3_settings_ui m3_apply_disable_quic_1 42 '' ''
grep -qx 'SET:forkop.settings.disable_quic=1' "$LOG"

PODKOP_VARIANT=experimental PODKOP_UCI=podkop
_m3_settings_ui m3_sec 42 '' ''
_keyboard '.inline_keyboard[1][0].callback_data=="m3_choose"'
_m3_settings_ui m3_choose_balance 42 '' ''
grep -qx 'SET:podkop.main.server_choice=balance' "$LOG"
_m3_section_extra m3_mixed 42 '' ''
_keyboard '.inline_keyboard[0][0].callback_data=="m3_port"'
_m3_section_extra m3_port 42 '' ''
_keyboard '.inline_keyboard[0][0].callback_data=="m3_sec"'
[ "$(sed -n '1p' "$STATE_FILE")" = wait_m3_port ]
_m3_section_extra STATE_INPUT 42 2083 wait_m3_port
grep -qx 'SET:podkop.main.mixed_proxy_port=2083' "$LOG"
echo 'UI routing, action, mixed, and settings callbacks: OK'

