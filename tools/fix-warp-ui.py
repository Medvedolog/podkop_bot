from pathlib import Path

p = Path("podkop_bot.sh")
s = p.read_text()


def one(old: str, new: str, desc: str) -> None:
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"{desc}: expected one anchor, got {n}")
    s = s.replace(old, new, 1)


one(
    "                    tier3) printf 'прокси бота' ;;\n                    tier4) printf 'напрямую' ;;\n",
    "                    tier3) printf 'прокси бота' ;;\n                    warp_rescue) printf 'WARP Rescue' ;;\n                    tier4) printf 'напрямую' ;;\n",
    "route key display",
)

one(
    "            # LAST_ROUTE_FAST holds the current tier key: tier1, tier2_N, tier3, tier4, tier5.\n",
    "            # LAST_ROUTE_FAST holds the current tier key: tier1, tier2_N, tier3,\n            # warp_rescue, tier4 or tier5.\n",
    "settings chain comment",
)

# Bot Settings -> "Порядок подключения": insert WARP between tier3 and Direct.
tier3_anchor = '$(_fmt_tier "tier3" "Прокси бота (${_cp_esc})")'
a = s.find(tier3_anchor)
if a < 0:
    raise SystemExit("bot settings tier3 anchor missing")
marker = '            if [ "$tr" != "socks" ]; then\n'
b = s.find(marker, a)
if b < 0:
    raise SystemExit("bot settings direct marker missing")
block = """            # WARP Rescue is a real transport tier between configured proxies and Direct.
            # Dormant means Revolver is armed but its localhost SOCKS is not running yet.
            local _wr_enabled _wr_port _wr_state
            _wr_enabled=$(_warp_rescue_cfg_get enabled 2>/dev/null || true)
            if [ "$tr" != "direct" ] && [ "$_wr_enabled" = "1" ]; then
                _wr_port=$(_warp_rescue_cfg_get socks_port 2>/dev/null || true)
                case "$_wr_port" in ''|*[!0-9]*) _wr_port=18191 ;; esac
                if _warp_rescue_pid_alive; then _wr_state="ON-AIR"; else _wr_state="ожидание Revolver"; fi
                tr_chain="${tr_chain}
$(_fmt_tier "warp_rescue" "WARP Rescue (127.0.0.1:${_wr_port}, ${_wr_state})")"
                _tier=$((_tier + 1))
            fi
"""
s = s[:b] + block + s[b:]

# Proxy connection list: render the same runtime tier and its current state.
old_comment = "            # tier4/tier5 always exist — say so, so the chain has no invisible parts.\n"
if s.count(old_comment) != 1:
    raise SystemExit(f"proxy chain final tiers comment: expected one anchor, got {s.count(old_comment)}")
block = r'''            # WARP Rescue is owned by Revolver, but belongs in this ordered runtime chain.
            local _wr_enabled _wr_port _wr_state _wr_lat
            _wr_enabled=$(_warp_rescue_cfg_get enabled 2>/dev/null || true)
            if [ "$_wr_enabled" = "1" ]; then
                _wr_port=$(_warp_rescue_cfg_get socks_port 2>/dev/null || true)
                case "$_wr_port" in ''|*[!0-9]*) _wr_port=18191 ;; esac
                _wr_lat=$(grep '^warp_rescue=' "$SOCKS_PROBE_FILE" 2>/dev/null | cut -d= -f2 | cut -d' ' -f1)
                if _warp_rescue_pid_alive; then
                    _wr_state="ON-AIR${_wr_lat:+ · $_wr_lat}"
                else
                    _wr_state="ожидает Revolver"
                fi
                _row_lbl=""; [ "${LAST_ROUTE:-}" = "warp_rescue" ] && _row_lbl=" ${E_PLAY}"
                list_text=$(printf '%s\
\
<code>warp_rescue</code>%s WARP Rescue <code>socks5h://127.0.0.1:%s</code> — <i>%s</i>' \
                    "$list_text" "$_row_lbl" "$_wr_port" "$_wr_state")
            fi

            # Direct and emergency IPs are the final two tiers.
'''
s = s.replace(old_comment, block, 1)

# "Проверить все": enabled Rescue must be a real test, not an invisible tier.
probe_anchor = '            local _t3_test; _t3_test=$(uci -q get podkop_bot.settings.custom_proxy 2>/dev/null)\n'
a = s.find(probe_anchor)
if a < 0:
    raise SystemExit("test-all tier3 anchor missing")
marker = "            unset -f _probe_channel _append_channel\n"
b = s.find(marker, a)
if b < 0:
    raise SystemExit("test-all cleanup marker missing")
block = r'''            # Manual "Проверить все" includes the real WARP runtime tier.
            local _wr_test_enabled _wr_test_proxy
            _wr_test_enabled=$(_warp_rescue_cfg_get enabled 2>/dev/null || true)
            if [ "$_wr_test_enabled" = "1" ]; then
                _wr_test_proxy=$(_warp_rescue_proxy 1 2>/dev/null || true)
                if [ -n "$_wr_test_proxy" ]; then
                    _probe_channel "$_wr_test_proxy"
                    _append_channel "WARP Rescue" "$(html_escape "$_wr_test_proxy")"
                else
                    CH_INET_OK=0; CH_INET_MS="—"; CH_TG_OK=0; CH_TG_REACH=0
                    CH_TG_MS="—"; CH_TG_CODE="000"; CH_TG_DETAIL="не удалось запустить"
                    _append_channel "WARP Rescue" "Revolver не поднял SOCKS"
                fi
            fi
'''
s = s[:b] + block + s[b:]

p.write_text(s)
