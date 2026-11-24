#!/bin/sh
# Pure mock UCI: ordered config dns_server rows, no router writes.
set -eux
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sed -n '/^# --- 0.20.3-dev4: native ordered/,/^# --- end 0.20.3-dev4 native DNS rows/p' podkop_bot.sh > "$tmp/dns.sh"
[ -s "$tmp/dns.sh" ]
sh -n podkop_bot.sh
sh -n "$tmp/dns.sh"
. "$tmp/dns.sh"
LOG="$tmp/uci.log"
: > "$LOG"
PODKOP_UCI=podkop
PODKOP_VARIANT=experimental
_podkop_exp_v2() { [ "$PODKOP_VARIANT" = experimental ]; }
_m3x_ip() { case "$1" in 2001:db8::1) return 0 ;; *) return 1 ;; esac; }
_m3x_ipv4() { printf '%s\n' "$1" | awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++)if($i !~ /^[0-9]+$/ || length($i)>3 || $i+0>255)exit 1}'; }
_fk_valid_domain() { case "$1" in dns.google|resolver.example) return 0 ;; *) return 1 ;; esac; }
uci() {
    [ "$1" = -q ] && shift
    case "$1" in
        show)
            [ "$2" = podkop ] || return 1
            printf '%s\n' 'podkop.settings=settings' 'podkop.src1=source' \
                'podkop.@dns_server[0]=dns_server' \
                "podkop.@dns_server[0].type='udp'" \
                "podkop.@dns_server[0].server='1.1.1.1'" \
                'podkop.main=section' 'podkop.@dns_server[1]=dns_server' \
                "podkop.@dns_server[1].type='doh'" \
                "podkop.@dns_server[1].server='dns.google/dns-query'" ;;
        get)
            case "$2" in
                podkop.settings) echo settings ;;
                'podkop.@dns_server[0].type') echo udp ;;
                'podkop.@dns_server[0].server') echo 1.1.1.1 ;;
                'podkop.@dns_server[1].type') echo doh ;;
                'podkop.@dns_server[1].server') echo dns.google/dns-query ;;
                *) return 1 ;;
            esac ;;
        add) printf 'ADD:%s:%s\n' "$2" "$3" >> "$LOG"; echo cfgd123 ;;
        set|delete|reorder|revert) printf '%s:%s\n' "$1" "$2" >> "$LOG" ;;
        *) return 1 ;;
    esac
}
_fk_txn_commit_reload() { printf 'COMMIT\n' >> "$LOG"; }
_fk_txn_fail_msg() { echo "Transaction error $1"; }
[ "$(_m4_dns_count)" -eq 2 ]
[ "$(_m4_dns_path 1)" = 'podkop.@dns_server[1]' ]
[ "$(_m4_dns_abspos 0)" = 2 ]
[ "$(_m4_dns_abspos 1)" = 4 ]
if _m4_dns_path 2; then exit 1; fi
if _m4_dns_path '0;reboot'; then exit 1; fi
_m4_dns_apply add 0 'dot resolver.example:853'
grep -qx 'ADD:podkop:dns_server' "$LOG"
grep -qx 'set:podkop.cfgd123.type=dot' "$LOG"
grep -qx 'set:podkop.cfgd123.server=resolver.example:853' "$LOG"
_m4_dns_apply edit 0 'provider'
grep -qx 'set:podkop.@dns_server[0].type=provider' "$LOG"
grep -qx 'delete:podkop.@dns_server[0].server' "$LOG"
_m4_dns_apply down 0 ''
grep -qx 'reorder:podkop.@dns_server[0]=4' "$LOG"
_m4_dns_apply up 1 ''
grep -qx 'reorder:podkop.@dns_server[1]=2' "$LOG"
_m4_dns_apply del 0 ''
grep -qx 'delete:podkop.@dns_server[0]' "$LOG"
cp "$LOG" "$tmp/before"
for value in 'https://dns.google/dns-query' 'udp' 'provider anything' 'dns.google' \
    'dot dns.google:65536' 'udp 999.1.1.1' 'doh dns.google/' \
    'udp dns.google/dns-query' 'dot dns.google;reboot' 'tcp 1.1.1.1'; do
    if _m4_dns_apply add 0 "$value"; then echo "accepted invalid DNS: $value" >&2; exit 1; fi
done
if _m4_dns_apply edit 99 'udp 1.1.1.1'; then exit 1; fi
if _m4_dns_apply up 0 ''; then exit 1; fi
if _m4_dns_apply down 1 ''; then exit 1; fi
PODKOP_VARIANT=forkop
if _m4_dns_apply add 0 'udp 1.1.1.1'; then exit 1; fi
PODKOP_VARIANT=experimental
cmp "$LOG" "$tmp/before"
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
_m4_dns_ui m4_dns 42 '' ''
jq -e '.inline_keyboard[0][0].callback_data == "m4_dns_item_0"' "$tmp/kb.json" >/dev/null
_m4_dns_ui m4_dns_item_1 42 '' ''
jq -e '.inline_keyboard[1][0].callback_data == "m4_dns_up_1"' "$tmp/kb.json" >/dev/null
_m4_dns_ui m4_dns_add 42 '' ''
[ "$(sed -n '1p' "$STATE_FILE")" = wait_m4_dns_add ]
_m4_dns_ui STATE_INPUT 42 'udp 8.8.8.8' wait_m4_dns_add
grep -qx 'set:podkop.cfgd123.server=8.8.8.8' "$LOG"
echo 'PASS 0.20.3-dev4 Podkop 0.8 DNS upstream ordered rows, edits, validation, UI, rollback delegation'
