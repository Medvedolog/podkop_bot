#!/bin/sh
# Contract tests on Forkop 2 UCI/Clash fixtures without router/network access.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

awk '/^forkop_v2_section_catalog\(\) \{/{active=1} /^forkop_child_count\(\) \{/{active=0} active{print}' \
    podkop_bot.sh > "$tmp/catalog.sh"
sh -n "$tmp/catalog.sh"
cat > "$tmp/forkop.uci" <<'CONFIG'
forkop.settings=settings
forkop.settings.config_version='2.0.0'
forkop.main=section
forkop.main.action='connection'
forkop.main.label='Primary'
forkop.main.enabled='1'
forkop.link0=connection_link
forkop.link0.section='main'
forkop.link0.uri='vless://PRIVATE-SERVER-SECRET'
forkop.sub0=subscription_url
forkop.sub0.section='main'
forkop.test0=urltest
forkop.test0.section='main'
forkop.fb0=fallback_group
forkop.fb0.section='main'
forkop.tun0=tunnel
forkop.tun0.section='main'
forkop.if0=section_interface
forkop.if0.section='main'
forkop.listener0=server
forkop.listener0.protocol='mixed'
forkop.listener0.routing_section='main'
CONFIG
(
    . "$tmp/catalog.sh"
    PODKOP_UCI=forkop
    _forkop_v2() { return 0; }
    uci() { [ "$*" = "-q show forkop" ] || return 1; cat "$tmp/forkop.uci"; }
    result=$(forkop_v2_section_catalog)
    [ "$result" = 'main|Primary|connection|1|1|1|1|1|1|1' ] || {
        echo "FAIL: Forkop 2 child/section counts: $result" >&2; exit 1;
    }
    case "$result" in *PRIVATE*) echo "FAIL: exposed secret in read-only catalog" >&2; exit 1 ;; esac
)

cat > "$tmp/proxies.json" <<'JSON'
{"proxies":{"main":{"type":"Selector","now":"main/Fallback","all":["main/URLTest","main/Fallback"]},"main/URLTest":{"type":"URLTest","now":"server-a","all":["server-a","server-b"]},"main/Fallback":{"type":"Fallback","now":"server-b","all":["server-a","server-b"]},"server-a":{"type":"VLESS","history":[{"delay":74}]},"server-b":{"type":"Hysteria2","history":[{"delay":98}]}}}
JSON
# Use the exact jq program embedded in the bot, not a reimplemented copy.
python3 - "$tmp/page.jq" <<'PY'
import pathlib, re, sys
s = pathlib.Path('podkop_bot.sh').read_text()
pat = r'page_tsv=\$\(echo "\$proxies" \| jq -r \\.*?--argjson groups .*?\\\s*\n\s*' + "'\\s*\\n(.*?)\\n\\s*' 2>/dev/null\\)"
m = re.search(pat, s, re.S)
if not m:
    raise SystemExit('FAIL: Forkop 2 proxy page jq program not found')
pathlib.Path(sys.argv[1]).write_text(m.group(1) + '\n')
PY
out=$(jq -r --arg sel main --argjson groups true --argjson s 0 --argjson e 9999 \
    -f "$tmp/page.jq" "$tmp/proxies.json")
[ "$(printf '%s\n' "$out" | wc -l)" -eq 2 ] || {
    echo "FAIL: nested Forkop 2 groups missing from proxy list" >&2; exit 1;
}
printf '%s' "$out" | grep -q 'main/URLTest' || exit 1
printf '%s' "$out" | grep -q 'main/Fallback' || exit 1
[ "$(jq -r --arg sel main --argjson groups false --argjson s 0 --argjson e 9999 \
    -f "$tmp/page.jq" "$tmp/proxies.json" | wc -l)" -eq 0 ] || {
    echo "FAIL: legacy provider filtering changed unexpectedly" >&2; exit 1;
}
grep -Fq 'case "$cmd" in sections_menu|set_sec_*|do_set_sec_*)' podkop_bot.sh
grep -Fq 'for _tun in $_si_tunnels' podkop_bot.sh
echo 'Forkop 2 sections, incoming server/tunnel inventory and nested proxy groups: OK'
