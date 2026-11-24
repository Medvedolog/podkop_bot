#!/bin/sh
# Mocked modern DNS/LAN editors, no live UCI writes.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sed -n '/^# --- 0.20.3 modern global DNS/,/^# --- end 0.20.3 modern global/p' podkop_bot.sh > "$tmp/modern-extra.sh"
[ -s "$tmp/modern-extra.sh" ]
sh -n podkop_bot.sh
sh -n "$tmp/modern-extra.sh"
. "$tmp/modern-extra.sh"

LOG="$tmp/uci.log"
: > "$LOG"
PODKOP_UCI=forkop
PODKOP_VARIANT=forkop
_forkop_v2() { [ "$PODKOP_VARIANT" = forkop ]; }
_podkop_exp_v2() { [ "$PODKOP_VARIANT" = experimental ]; }
_fk_valid_url() { case "$1" in https://dns.google/dns-query) return 0 ;; *) return 1 ;; esac; }
_fk_valid_domain() { case "$1" in dns.google) return 0 ;; *) return 1 ;; esac; }
validate_ip_or_cidr() { [ "$1" = 192.0.2.0/24 ]; }
uci() {
    [ "$1" = -q ] && shift
    case "$1" in
        get)
            case "$2" in
                forkop.settings|podkop.settings) echo settings ;;
                forkop.settings.dns_server) echo '77.88.8.8 1.1.1.1' ;;
                forkop.settings.bootstrap_dns_server) echo '77.88.8.8 8.8.8.8' ;;
                podkop.settings.bootstrap_dns_server) echo '77.88.8.8' ;;
                forkop.settings.source_network_interfaces|podkop.settings.source_network_interfaces) echo br-lan ;;
                podkop.settings.routing_excluded_ips) echo 192.0.2.0/24 ;;
                network.lanif) echo interface ;;
                *) return 1 ;;
            esac ;;
        add_list) printf 'ADD:%s\n' "$2" >> "$LOG" ;;
        del_list) printf 'DEL:%s\n' "$2" >> "$LOG" ;;
        revert) printf 'REVERT:%s\n' "$2" >> "$LOG" ;;
        *) return 1 ;;
    esac
}
_fk_stage_set() { printf 'SET:%s=%s\n' "$1" "$2" >> "$LOG"; }
_fk_txn_commit_reload() { echo COMMIT >> "$LOG"; }
_fk_txn_fail_msg() { echo "TXN $1"; }

[ "$(_m3x_kind dns_server)" = list ]
[ "$(_m3x_kind bootstrap_dns_server)" = list ]
[ "$(_m3x_kind routing_excluded_ips)" = list ]
_m3x_apply add dns_server 'https://dns.google/dns-query'
grep -qx 'ADD:forkop.settings.dns_server=https://dns.google/dns-query' "$LOG"
_m3x_apply add bootstrap_dns_server '1.0.0.1'
grep -qx 'ADD:forkop.settings.bootstrap_dns_server=1.0.0.1' "$LOG"
_m3x_apply add source_network_interfaces 'lanif'
grep -qx 'ADD:forkop.settings.source_network_interfaces=lanif' "$LOG"
_m3x_apply add routing_excluded_ips '@system'
grep -qx 'ADD:forkop.settings.routing_excluded_ips=@system' "$LOG"
cp "$LOG" "$tmp/prev"
if _m3x_apply add dns_server 'https://dns.google/dns-query;reboot'; then exit 1; fi
if _m3x_apply add dns_server '999.1.2.3'; then exit 1; fi
if _m3x_apply del dns_server '77.88.8.8
1.1.1.1'; then exit 1; fi
if _m3x_apply add source_network_interfaces 'missing_interface'; then exit 1; fi
if _m3x_apply del source_network_interfaces 'br-lan'; then exit 1; fi
if _m3x_apply add source_network_interfaces 'lanif\nlanif'; then exit 1; fi
cmp "$LOG" "$tmp/prev"

PODKOP_UCI=podkop
PODKOP_VARIANT=experimental
if _m3x_kind dns_server >/dev/null 2>&1; then exit 1; fi
[ "$(_m3x_kind bootstrap_dns_server)" = scalar ]
_m3x_apply set bootstrap_dns_server '8.8.4.4'
grep -qx 'SET:podkop.settings.bootstrap_dns_server=8.8.4.4' "$LOG"
_m3x_apply add routing_excluded_ips '198.51.100.2'
grep -qx 'ADD:podkop.settings.routing_excluded_ips=198.51.100.2' "$LOG"
cp "$LOG" "$tmp/prev"
if _m3x_apply set bootstrap_dns_server 'https://dns.google/dns-query'; then exit 1; fi
if _m3x_apply add routing_excluded_ips 'bad_ip'; then exit 1; fi
cmp "$LOG" "$tmp/prev"

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
_m3x_ui m3x_home 42 '' ''
jq -e '.inline_keyboard[0][0].callback_data=="m3x_dns"' "$tmp/kb.json" >/dev/null
_m3x_ui m3x_dns 42 '' ''
jq -e '.inline_keyboard[0][0].callback_data=="m3x_f_bootstrap_dns_server"' "$tmp/kb.json" >/dev/null
_m3x_ui m3x_net 42 '' ''
jq -e '.inline_keyboard[1][0].callback_data=="m3x_f_routing_excluded_ips"' "$tmp/kb.json" >/dev/null
_m3x_ui m3x_set_bootstrap_dns_server 42 '' ''
[ "$(sed -n '1p' "$STATE_FILE")" = wait_m3x_set_bootstrap_dns_server ]
_m3x_ui STATE_INPUT 42 9.9.9.9 wait_m3x_set_bootstrap_dns_server
grep -qx 'SET:podkop.settings.bootstrap_dns_server=9.9.9.9' "$LOG"
echo 'PASS 0.20.3 modern DNS/LAN editors: allowed fields, validation, transactional callback, JSON keyboards'
