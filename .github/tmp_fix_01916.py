from pathlib import Path

p = Path('podkop_bot.sh')
s = p.read_text()
start = s.index('# Measure Telegram Bot API reachability through one proxy endpoint.')
end = s.index('# Probe all configured proxy endpoints in parallel and write structured results', start)
fixed = '''# Measure Telegram Bot API reachability through one proxy endpoint.
# Outputs latency in ms or "timeout". getMe is lightweight and, unlike gstatic,
# proves that this exact path reaches api.telegram.org. 401/429 are transport-positive:
# Telegram answered, even though the application request itself was rejected.
probe_telegram_proxy_latency() {
    local _proxy="$1" _tmp _out _code _time
    _tmp=$(mktemp /tmp/podkop_tg_follow.XXXXXX 2>/dev/null) || { echo "timeout"; return; }
    _out=$(curl -s -k -x "$_proxy" --connect-timeout 4 --max-time 8 \\
        -o "$_tmp" -w "%{http_code}:%{time_total}" "${API_URL}/getMe" 2>/dev/null)
    _code="${_out%%:*}"
    _time="${_out#*:}"
    if { [ "$_code" = "200" ] && jq -e '.ok == true' "$_tmp" >/dev/null 2>&1; } || \\
       jq -e '.error_code == 401 or .error_code == 429' "$_tmp" >/dev/null 2>&1; then
        awk -v t="${_time:-0}" 'BEGIN{printf "%dms", int(t*1000)}'
    else
        printf 'timeout'
    fi
    rm -f "$_tmp" 2>/dev/null
}

'''
s = s[:start] + fixed + s[end:]
s = s.replace('# A gstatic 204 does not prove that a Telegram long-poll will survive, therefore\n# this signal is used only to grant one hysteresis hold, never as a route success.', '# A successful getMe proves Bot API reachability but not that a 50s long-poll will\n# survive; this signal grants one hysteresis hold, never an authoritative route success.')
p.write_text(s)

s = p.read_text()
assert 'probe_telegram_proxy_latency() {' in s
assert '\\nprobe_telegram_proxy_latency()' not in s
assert s.count('probe_telegram_proxy_latency() {') == 1
assert s.count('probe_telegram_proxy_latency "') >= 3
