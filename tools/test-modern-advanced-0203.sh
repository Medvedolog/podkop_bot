#!/bin/sh
# Cross-provider advanced UCI editor: mocked transaction and Telegram markup.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sed -n '/^# --- 0.20.3-dev4: typed advanced/,/^# --- end 0.20.3-dev4 typed advanced options/p' podkop_bot.sh > "$tmp/advanced.sh"
[ -s "$tmp/advanced.sh" ]
sh -n podkop_bot.sh
sh -n "$tmp/advanced.sh"
. "$tmp/advanced.sh"
LOG="$tmp/ops"
: > "$LOG"
PODKOP_UCI=forkop PODKOP_VARIANT=forkop
_forkop_v2() { [ "$PODKOP_VARIANT" = forkop ]; }
_podkop_exp_v2() { [ "$PODKOP_VARIANT" = experimental ]; }
_m3x_valid() { [ "$1" = source_network_interfaces ] && [ "$2" = wan ]; }
_fk_stage_set() { printf 'SET:%s=%s\n' "$1" "$2" >> "$LOG"; }
_fk_stage_delete() { printf 'DELETE:%s\n' "$1" >> "$LOG"; }
_fk_txn_commit_reload() { printf 'COMMIT\n' >> "$LOG"; }
_fk_txn_fail_msg() { echo "error $1"; }
uci() {
    [ "$1" = -q ] && shift
    case "$1:$2" in
        get:forkop.settings|get:podkop.settings) echo settings ;;
        get:forkop.main|get:podkop.main) echo section ;;
        get:network.wan) echo interface ;;
        get:forkop.settings.dns_detour_section) echo main ;;
        get:forkop.settings.output_network_interface|get:podkop.settings.output_network_interface) echo wan ;;
        get:forkop.settings.badwan_monitored_interfaces) echo wan ;;
        get:podkop.settings.bittorrent_section) echo main ;;
        get:forkop.settings.dns_strategy) echo prefer_ipv4 ;;
        get:podkop.settings.dns_mode) echo order ;;
        *) return 1 ;;
    esac
}
[ "$(_m4_adv_kind dns_main_fallback_strategy)" = enum ]
[ "$(_m4_adv_kind badwan_reload_delay)" = scalar ]
_m4_adv_apply dns_main_fallback_strategy sequential
grep -Fqx 'SET:forkop.settings.dns_main_fallback_strategy=sequential' "$LOG"
_m4_adv_apply dns_bootstrap_fallback_strategy parallel
grep -Fqx 'SET:forkop.settings.dns_bootstrap_fallback_strategy=parallel' "$LOG"
_m4_adv_apply dns_strategy ipv6_only
grep -Fqx 'SET:forkop.settings.dns_strategy=ipv6_only' "$LOG"
_m4_adv_apply unmatched_dns_mode router
_m4_adv_apply dns_detour_enabled 1
_m4_adv_apply dns_detour_section main
_m4_adv_apply enable_output_network_interface 1
_m4_adv_apply output_network_interface wan
_m4_adv_apply output_network_interface auto
grep -Fqx 'DELETE:forkop.settings.output_network_interface' "$LOG"
_m4_adv_apply enable_badwan_interface_monitoring 1
_m4_adv_apply badwan_reload_delay 2000
_m4_adv_apply dns_timeout 10s
_m4_adv_apply dns_rewrite_ttl 0
_m4_adv_apply bittorrent_direct 1
cp "$LOG" "$tmp/before"
for pair in 'dns_strategy as_is' 'dns_timeout 1000s' 'dns_rewrite_ttl -1' \
    'badwan_reload_delay hello' 'dns_detour_section nope' \
    'output_network_interface x;reboot' 'dns_main_fallback_strategy bad' \
    'dns_detour_enabled 2' 'evil_config 1'; do
    field=$(printf '%s' "$pair" | cut -d' ' -f1)
    value=$(printf '%s' "$pair" | cut -d' ' -f2-)
    if _m4_adv_apply "$field" "$value"; then echo "invalid accepted: $pair" >&2; exit 1; fi
done
cmp "$LOG" "$tmp/before"
PODKOP_UCI=podkop PODKOP_VARIANT=experimental
[ "$(_m4_adv_kind dns_mode)" = enum ]
_m4_adv_apply dns_mode fastest
_m4_adv_apply dns_addresses both
_m4_adv_apply ipv6_routing podkop
_m4_adv_apply bittorrent_section main
_m4_adv_apply bittorrent section
_m4_adv_apply bittorrent block
_m4_adv_apply output_network_interface auto
grep -Fqx 'SET:podkop.settings.dns_mode=fastest' "$LOG"
grep -Fqx 'SET:podkop.settings.ipv6_routing=podkop' "$LOG"
cp "$LOG" "$tmp/before2"
if _m4_adv_apply dns_strategy prefer_ipv4; then exit 1; fi
if _m4_adv_apply bittorrent reconfigure; then exit 1; fi
cmp "$LOG" "$tmp/before2"
STATE_FILE="$tmp/state"
LAST_MENU_MSG_FILE="$tmp/menu"
CALLBACK_MSG_ID=42
E_SET='[SET]' E_WARN='[WARN]' E_EDIT='[EDIT]'
echo 42 > "$LAST_MENU_MSG_FILE"
send_or_edit() { printf '%s\n' "$3" > "$tmp/kb.json"; }
send_message() { :; }
delete_message() { :; }
json_escape() { printf '%s' "$1"; }
html_escape() { printf '%s' "$1"; }
_utf8_head() { printf '%s' "$1"; }
_m4_adv_ui m4_adv 42 '' ''
jq -e '[.inline_keyboard[][] | .callback_data] | index("m4_adv_field_dns_mode") != null' "$tmp/kb.json" >/dev/null
_m4_adv_ui m4_adv_field_dns_mode 42 '' ''
jq -e '[.inline_keyboard[][] | .callback_data] | index("m4_adv_pick_dns_mode.fastest") != null' "$tmp/kb.json" >/dev/null
_m4_adv_ui m4_adv_pick_dns_mode.fastest 42 '' ''
jq -e '.inline_keyboard[0][0].callback_data == "m4_adv_set_dns_mode.fastest"' "$tmp/kb.json" >/dev/null
_m4_adv_ui m4_adv_input_dns_rewrite_ttl 42 '' ''
[ "$(sed -n '1p' "$STATE_FILE")" = wait_m4_adv_dns_rewrite_ttl ]
_m4_adv_ui STATE_INPUT 42 180 wait_m4_adv_dns_rewrite_ttl
grep -Fqx 'SET:podkop.settings.dns_rewrite_ttl=180' "$LOG"
echo 'PASS 0.20.3-dev4 typed Forkop DNS fallback/detour/WAN and Podkop DNS/IPv6/BT editors'
