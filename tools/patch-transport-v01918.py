#!/usr/bin/env python3
"""Apply the 0.19.18 POLL/WARP transport fix to podkop_bot.sh."""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-transport-v01918.py <podkop_bot.sh>")

p = Path(sys.argv[1])
s = p.read_text()
MARK = "PODKOP_TRANSPORT_PATCH_V2"
if MARK in s:
    raise SystemExit(0)


def replace(old: str, new: str, count: int = 1) -> None:
    global s
    got = s.count(old)
    if got != count:
        raise SystemExit(f"transport patch anchor mismatch: expected {count}, found {got}: {old[:100]!r}")
    s = s.replace(old, new, count)


s = s.replace("# Podkop Telegram Bot v0.19.17", "# Podkop Telegram Bot v0.19.18", 1)
s = s.replace('BOT_VERSION="0.19.17"', 'BOT_VERSION="0.19.18"', 1)

warp_helpers = r'''
# PODKOP_TRANSPORT_PATCH_V2
# WARP Rescue transport provider.  The revolver owns the WARP process; the bot
# only consumes its localhost SOCKS endpoint and may ask the controller to arm
# it when Rescue was explicitly enabled by the operator.
_WARP_RESCUE_CONFIG="/etc/podkop_bot/warpscout.conf"
_WARP_RESCUE_PID_FILE="${BOT_DIR}/warpscout_rescue_socks.pid"
_WARP_RESCUE_TRIGGER_TS_FILE="${BOT_DIR}/warp_rescue_trigger_ts"

_warp_rescue_cfg_get() {
    [ -r "$_WARP_RESCUE_CONFIG" ] || return 1
    sed -n "s/^$1=//p" "$_WARP_RESCUE_CONFIG" 2>/dev/null | head -1
}

_warp_rescue_pid_alive() {
    [ -s "$_WARP_RESCUE_PID_FILE" ] || return 1
    local _p
    _p=$(cat "$_WARP_RESCUE_PID_FILE" 2>/dev/null)
    case "$_p" in ''|*[!0-9]*) return 1 ;; esac
    kill -0 "$_p" 2>/dev/null
}

_warp_rescue_proxy() {
    local _allow_start="${1:-0}" _enabled _port _now _last=0 _resp _i
    _enabled=$(_warp_rescue_cfg_get enabled 2>/dev/null || true)
    [ "$_enabled" = "1" ] || return 1
    _port=$(_warp_rescue_cfg_get socks_port 2>/dev/null || true)
    case "$_port" in ''|*[!0-9]*) _port=18191 ;; esac

    if ! _warp_rescue_pid_alive; then
        [ "$_allow_start" = "1" ] || return 1
        _now=$(date +%s 2>/dev/null || echo 0)
        [ -r "$_WARP_RESCUE_TRIGGER_TS_FILE" ] && _last=$(cat "$_WARP_RESCUE_TRIGGER_TS_FILE" 2>/dev/null || echo 0)
        case "$_last" in ''|*[!0-9]*) _last=0 ;; esac
        if [ $((_now - _last)) -ge 20 ] 2>/dev/null; then
            printf '%s\n' "$_now" > "$_WARP_RESCUE_TRIGGER_TS_FILE"
            _resp=$(ubus call podkop_bot_warpscout_rescue trigger '{}' 2>/dev/null || true)
            printf '%s' "$_resp" | jq -e '.ok == true' >/dev/null 2>&1 || return 1
        fi
        _i=0
        while ! _warp_rescue_pid_alive && [ "$_i" -lt 10 ]; do
            sleep 1
            _i=$((_i + 1))
        done
    fi
    _warp_rescue_pid_alive || return 1
    printf 'socks5h://127.0.0.1:%s' "$_port"
}

_try_warp_rescue() {
    local _args="$1" _max_time="$2" _ct="$3" _proxy
    [ "$_t_policy" != "direct" ] || return 1
    _proxy=$(_warp_rescue_proxy 1) || return 1
    logger -t podkop-bot "[Transport] Trying WARP Rescue for ${_ROUTE_PROFILE:-unknown}"
    if _try_curl "-x $_proxy" "$_max_time" "$_args" "$_ct"; then
        ROUTE_KEY="warp_rescue"
        ROUTE_NAME="WARP Rescue"
        return 0
    fi
    logger -t podkop-bot "[Transport] WARP Rescue failed for ${_ROUTE_PROFILE:-unknown}"
    return 1
}

'''
replace("# _try_all_tiers: full cascade including custom/direct/emergency.\n", warp_helpers + "# _try_all_tiers: full cascade including custom/WARP/direct/emergency.\n")

replace(
'''    # POLL-only demotion hysteresis.  If the independent follower has a
''',
'''    # WARP Rescue is a genuine runtime tier, not diagnostics decoration.  It is
    # attempted after configured proxies and before Direct.
    if _try_warp_rescue "$args" "$max_time" "$ct_fast"; then
        return 0
    fi
    [ "${_TG_NO_DEMOTE:-0}" = "1" ] && return 1

    # POLL-only demotion guard.  If the independent follower still proves at
'''
)

replace(
'''    # fresh positive proxy sample, one failed long-poll cascade is treated as transient.
    # The next POLL retries the proxy stack; two consecutive failures still allow Direct.
    if [ "${_ROUTE_PROFILE:-fast}" = "poll" ] && [ "$_t_policy" != "direct" ]; then
        if _poll_follower_has_fresh_proxy; then
            POLL_PROXY_FAIL_STREAK=$(( ${POLL_PROXY_FAIL_STREAK:-0} + 1 ))
            if [ "$POLL_PROXY_FAIL_STREAK" -lt 2 ]; then
                _TG_NO_DEMOTE=1
                logger -t podkop-bot "[Transport] POLL proxy cascade failed. streak=${POLL_PROXY_FAIL_STREAK} follower=alive action=hold"
                return 1
            fi
            logger -t podkop-bot "[Transport] POLL proxy cascade failed. streak=${POLL_PROXY_FAIL_STREAK} follower=alive action=demote"
        else
            POLL_PROXY_FAIL_STREAK=0
            logger -t podkop-bot "[Transport] POLL proxy cascade failed. follower=none_or_stale action=demote"
        fi
    fi
''',
'''    # least one proxy route can reach Telegram with a fresh getMe, a failed 50s
    # getUpdates is an idle-tunnel/POLL failure, not proof that the proxy path is
    # dead.  Never fall through to Direct on that evidence alone.  Full discovery
    # is repeated on the next POLL, so another healthy proxy can take over.
    if [ "${_ROUTE_PROFILE:-fast}" = "poll" ] && [ "$_t_policy" != "direct" ]; then
        if _poll_follower_has_fresh_proxy; then
            POLL_PROXY_FAIL_STREAK=$(( ${POLL_PROXY_FAIL_STREAK:-0} + 1 ))
            _TG_NO_DEMOTE=1
            logger -t podkop-bot "[Transport] POLL proxy cascade failed. streak=${POLL_PROXY_FAIL_STREAK} follower=alive action=hold_direct"
            return 1
        fi
        POLL_PROXY_FAIL_STREAK=0
        logger -t podkop-bot "[Transport] POLL proxy cascade failed. follower=none_or_stale action=demote"
    fi
'''
)

replace(
'''            tier4)
                # On degraded path (tier4): periodically try SOCKS tiers before using direct.
''',
'''            warp_rescue)
                local _warp_proxy=""
                _warp_proxy=$(_warp_rescue_proxy 1 2>/dev/null || true)
                [ -n "$_warp_proxy" ] && \\
                _try_curl "-x $_warp_proxy" "$_max" "$_args" "$_ct_sticky" && {
                    LAST_ROUTE="warp_rescue"; LAST_ROUTE_NAME="WARP Rescue"
                    _write_route_state "$_ROUTE_PROFILE" "warp_rescue" "$LAST_ROUTE_NAME"
                    eval "$_rvar=warp_rescue"; return 0
                }
                ;;
            tier4)
                # On degraded path (tier4): periodically try proxy tiers before using direct.
'''
)

old_reprobe = '''                    elif [ -n "$_t_custom" ] && [ "$_t_policy" != "direct" ] && \\
                         _try_curl "$_t_ifflag -x $_t_custom" "$_max" "$_args" "2"; then
                        ROUTE_KEY="tier3"; ROUTE_NAME="Прокси бота (${_t_custom})"
                    else
                        ROUTE_KEY=""
                    fi
'''
new_reprobe = '''                    elif [ -n "$_t_custom" ] && [ "$_t_policy" != "direct" ] && \\
                         _try_curl "$_t_ifflag -x $_t_custom" "$_max" "$_args" "2"; then
                        ROUTE_KEY="tier3"; ROUTE_NAME="Прокси бота (${_t_custom})"
                    elif _try_warp_rescue "$_args" "$_max" "2"; then
                        :
                    else
                        ROUTE_KEY=""
                    fi
'''
replace(old_reprobe, new_reprobe, 2)

s = s.replace('tier1|tier2_*|tier3)', 'tier1|tier2_*|tier3|warp_rescue)')

replace(
'''    if [ -n "$_t_custom" ]; then
        _slots="$_slots tier3"
        (
            _lat=$(probe_telegram_proxy_latency "$_t_custom")
            printf 'tier3=%s url=%s\\n' "$_lat" "$(_mask_proxy "$(_proxy_endpoint "$_t_custom")")" > "$_probe_dir/tier3"
        ) & _pids="$_pids $!"
    fi

    # Reap exactly our workers; never use a bare wait in the bot shell.
''',
'''    if [ -n "$_t_custom" ]; then
        _slots="$_slots tier3"
        (
            _lat=$(probe_telegram_proxy_latency "$_t_custom")
            printf 'tier3=%s url=%s\\n' "$_lat" "$(_mask_proxy "$(_proxy_endpoint "$_t_custom")")" > "$_probe_dir/tier3"
        ) & _pids="$_pids $!"
    fi

    local _warp_follow=""
    _warp_follow=$(_warp_rescue_proxy 0 2>/dev/null || true)
    if [ -n "$_warp_follow" ]; then
        _slots="$_slots warp_rescue"
        (
            _lat=$(probe_telegram_proxy_latency "$_warp_follow")
            printf 'warp_rescue=%s\\n' "$_lat" > "$_probe_dir/warp_rescue"
        ) & _pids="$_pids $!"
    fi

    # Reap exactly our workers; never use a bare wait in the bot shell.
'''
)
replace(
'''    grep -Eq '^tier(1|2_[0-9]+|3)=[0-9]+ms([[:space:]]|$)' "$SOCKS_PROBE_FILE" 2>/dev/null
}
''',
'''    grep -Eq '^(tier(1|2_[0-9]+|3)|warp_rescue)=[0-9]+ms([[:space:]]|$)' "$SOCKS_PROBE_FILE" 2>/dev/null
}
'''
)

replace(
'''        if [ -n "$_t_custom" ]; then
            res=$(_do_curl_doc "$_t_ifflag -x $_t_custom")
            _is_telegram_response "$res" && {
                unset -f _do_curl_doc
                LAST_ROUTE_DOC="tier3"; return 0
            }
        fi
    fi
    if [ "$_t_policy" != "socks" ]; then
''',
'''        if [ -n "$_t_custom" ]; then
            res=$(_do_curl_doc "$_t_ifflag -x $_t_custom")
            _is_telegram_response "$res" && {
                unset -f _do_curl_doc
                LAST_ROUTE_DOC="tier3"; return 0
            }
        fi
        local _warp_doc=""
        _warp_doc=$(_warp_rescue_proxy 1 2>/dev/null || true)
        if [ -n "$_warp_doc" ]; then
            res=$(_do_curl_doc "-x $_warp_doc")
            _is_telegram_response "$res" && {
                unset -f _do_curl_doc
                LAST_ROUTE_DOC="warp_rescue"; return 0
            }
        fi
    fi
    if [ "$_t_policy" != "socks" ]; then
'''
)

replace(
'''        tier4)
            p_args="$if_flag"
            ;;
''',
'''        warp_rescue)
            local _warp_lat=""
            _warp_lat=$(_warp_rescue_proxy 0 2>/dev/null || true)
            [ -n "$_warp_lat" ] || { echo "Нет данных"; return; }
            p_args="-x $_warp_lat"
            ;;
        tier4)
            p_args="$if_flag"
            ;;
'''
)

s = s.replace(
    '# 1. 5-Tier Fallback Транспорт: Podkop SOCKS5 -> Резервные SOCKS -> Custom Proxy\n#    -> Direct -> Emergency IPs.',
    '# 1. Fallback Транспорт: Podkop SOCKS5 -> Резервные SOCKS -> Custom Proxy\n#    -> WARP Rescue -> Direct -> Emergency IPs.',
    1,
)
s = s.replace(
    '#       tier4               Direct\n#       tier5               Emergency hardcoded Telegram IPs',
    '#       warp_rescue         WARP Rescue localhost SOCKS (optional)\n#       tier4               Direct\n#       tier5               Emergency hardcoded Telegram IPs',
    1,
)

p.write_text(s)
