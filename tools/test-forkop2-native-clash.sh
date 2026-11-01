#!/bin/sh
# No network, no router changes. Test upstream Forkop's {status,body} wrapper.
set -eu
cd "$(dirname "$0")/.."
bot=podkop_bot.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
awk '/^_forkop_clash_cli\(\) \{/{p=1} /^# Fetch available community list names/{p=0} p{print}' "$bot" > "$tmp/clash.sh"
sh -n "$tmp/clash.sh"
cat > "$tmp/forkop" <<'EOF'
#!/bin/sh
[ "$1" = clash_api ] || exit 1
printf '%s %s\n' "$2" "$3" >> "$TEST_FORKOP_LOG"
case "$2:$3" in
 'GET:/proxies') printf '{"status":200,"body":"{\\"proxies\\":{\\"main\\":{\\"type\\":\\"Selector\\"}}}"}\n';;
 'PUT:/proxies/main') printf '{"status":204,"body":""}\n';;
 *) printf '{"status":403,"body":"denied"}\n';;
esac
EOF
chmod +x "$tmp/forkop"
(
. "$tmp/clash.sh"
PODKOP_BIN="$tmp/forkop"; PODKOP_UCI=forkop
CLASH_API=http://127.0.0.1:9090
TEST_FORKOP_LOG="$tmp/calls"; export TEST_FORKOP_LOG
: > "$TEST_FORKOP_LOG"
_forkop_v2(){ return 0; }
_podkop_exp_v2(){ return 1; }
lan_ipv4(){ echo ''; }
uci(){ echo ''; }
curl(){ return 7; }
got=$(clash_request /proxies)
printf '%s' "$got" | jq -e '.proxies.main.type=="Selector"' >/dev/null
clash_request /proxies/main PUT '{"name":"src1: Node A"}' >/dev/null
[ "$(grep -c '^PUT /proxies/main$' "$TEST_FORKOP_LOG")" = 1 ]
[ "$(grep -c '^GET /proxies$' "$TEST_FORKOP_LOG")" = 1 ]
if _forkop_clash_cli DELETE /connections '' >/dev/null; then exit 1; fi
)
echo 'PASS native Forkop2 Clash read + single-write fallback'
