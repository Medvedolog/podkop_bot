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
