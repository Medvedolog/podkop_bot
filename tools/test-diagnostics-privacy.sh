#!/bin/sh
# Isolate report generators: no router, real config, network, or Telegram.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
bot=podkop_bot.sh
{
    sed -n '/^_mask_proxy() {/,/^}/p' "$bot"
    sed -n '/^_podkop_init_state() {/,/^}/p' "$bot"
    sed -n '/^_status_severity() {/,/^}/p' "$bot"
    sed -n '/^_diag_route() {/,/^# SECTION 8:/p' "$bot"
} >"$tmp/functions"
cat >"$tmp/cases" <<'CASES'
set -eu
. "$1"
dir="$2"
CANARY='SYNTHETIC_PRIVATE_CANARY'
TOKEN='123456789:AA_Only_Test_8hdQdWvK_Credential_XYZ'
SOURCE_URI="https://subscriptions.test/private/$CANARY?bot=$TOKEN"
RAW_PROXY="socks5h://${CANARY}:abc%40DEF@proxy.test:1080"
export CANARY TOKEN SOURCE_URI RAW_PROXY
PODKOP_UCI=podkop PODKOP_VARIANT=podkop-exp
PODKOP_BIN=backend_stub PODKOP_INIT=init_stub
BOT_VERSION=0.20.2 LAST_ROUTE_POLL=tier2_1 LAST_ROUTE_FAST="$TOKEN"
SOCKS_STATE_FILE="$dir/state"; SOCKS_PROBE_FILE="$dir/probes"
printf '%s\n' 'tg_direct:unrelated' 'tg_transport=ok' "tg_direct=$TOKEN" "bad_$CANARY=fail" 'socks=up' >"$SOCKS_STATE_FILE"
printf '%s\n' "tier1=46ms url=$RAW_PROXY" "tier2_1=96 label=$SOURCE_URI" "tier3=$TOKEN" >"$SOCKS_PROBE_FILE"
uci() {
    if [ "$2" = get ]; then printf '%s\n' "$TOKEN"; else
        printf 'podkop.rules.%s=%s\npodkop_bot.settings.bot_token=%s\n' "$CANARY" "$SOURCE_URI" "$TOKEN"
    fi
}
logread() {
    printf 'podkop-bot[5]: [Transport] raw=%s\npodkop-bot: [Watchdog] token=%s\nprovider: %s\n' "$RAW_PROXY" "$TOKEN" "$SOURCE_URI"
}
_engine_status() {
    ENGINE_STATE=running ENGINE_SERVICE=podkop
    ENGINE_PID="$CANARY"
    # Even stderr from upstream and shell commands must not enter the file.
    printf '%s\n' "$TOKEN" >&2
}
clash_request() {
    case "$1" in
        /version) jq -nc --arg token "$TOKEN" '{version:$token,headers:{Authorization:$token}}' ;;
        /proxies) jq -nc --arg uri "$SOURCE_URI" --arg p "$RAW_PROXY" '{proxies:{group:{all:[$uri,$p]}}}' ;;
        /proxies/*subscriptions*) jq -nc --arg uri "$SOURCE_URI" '{delay:37,unexpected:$uri}' ;;
        *) jq -nc --arg tok "$TOKEN" '{delay:$tok,headers:{Authorization:$tok}}' ;;
    esac
}
get_selector_tag() { printf 'group'; }
forkop_v2() { [ "$PODKOP_VARIANT" = forkop ]; }
backend_stub() { printf 'diagnostic query=%s\n' "$SOURCE_URI"; printf 'error: %s\n' "$TOKEN" >&2; return 5; }
timeout() { shift; "$@"; }
init_stub() { [ "$1" = status ]; printf '%s\n' "$INIT_OUT"; return "$INIT_RC"; }

expect_absent() {
    if grep -F -e "$CANARY" -e "$TOKEN" -e 'abc%40DEF' -e 'proxy.test' -e 'subscriptions.test' "$1" >/dev/null; then
        printf 'sensitive fixture data in %s\n' "$1" >&2; exit 1
    fi
}
for variant in original evolution plus forkop netshift podkop-exp; do
    PODKOP_VARIANT="$variant"
    case "$variant" in
        plus) PODKOP_UCI=podkop-plus ;;
        forkop|netshift) PODKOP_UCI="$variant" ;;
        *) PODKOP_UCI=podkop ;;
    esac
    for mode in support diagnostics backend backend-config engine logs; do
        out="$dir/$variant-$mode.txt"
        run_internal_diagnostics "$out" "$mode"
        expect_absent "$out"
        grep -Fq 'не включены' "$out"
    done
done
grep -Fq 'Команда check_service: код завершения 5' "$dir/forkop-backend.txt"
grep -Fq 'Команда global_check: код завершения 5' "$dir/podkop-exp-backend.txt"
grep -Fq 'Движок: работает' "$dir/original-support.txt"
grep -Fq 'Настроек в UCI (число строк): 2' "$dir/forkop-support.txt"
grep -Fq 'Записей бота: 2' "$dir/netshift-logs.txt"
grep -Fq 'Задержка tier1: 46 мс' "$dir/plus-diagnostics.txt"
grep -Fq 'Clash API: отвечает' "$dir/podkop-exp-engine.txt"
run_upstream_health_report "$dir/upstream.txt" && exit 1
expect_absent "$dir/upstream.txt"
grep -Fq 'Прокси №1: 37 мс' "$dir/upstream.txt"
grep -Fq 'Прокси №2: нет результата' "$dir/upstream.txt"

[ "$(_mask_proxy "$RAW_PROXY?secret=$TOKEN#name")" = 'socks5h://***@proxy.test:1080' ]
[ "$(_mask_proxy "http://$CANARY@proxy.test:8080")" = 'http://***@proxy.test:8080' ]
[ "$(_mask_proxy "https://$CANARY:one@two@proxy.test:8443/path")" = 'https://***@proxy.test:8443' ]
[ "$(_mask_proxy "socks5h://$CANARY:123/bogus@proxy.test:1080")" = '[адрес скрыт]' ]
[ "$(_mask_proxy "socks5h://bob:b@proxy.test:1080?extra=x@y")" = '[адрес скрыт]' ]
[ "$(_mask_proxy 'http://[2001:db8::1]:8080')" = 'http://[2001:db8::1]:8080' ]

INIT_OUT=running INIT_RC=0; [ "$(_podkop_init_state)" = 1 ]
INIT_OUT='running (1/2)' INIT_RC=0; [ "$(_podkop_init_state)" = 1 ]
INIT_OUT='not running' INIT_RC=5; [ "$(_podkop_init_state)" = 0 ]
INIT_OUT='not running' INIT_RC=1; [ "$(_podkop_init_state)" = 0 ]
ENGINE_PROCESS_STATE=unknown; [ "$(_podkop_init_state)" = unknown ]
unset ENGINE_PROCESS_STATE
INIT_OUT=inactive INIT_RC=3; [ "$(_podkop_init_state)" = unknown ]
INIT_OUT=running INIT_RC=127; [ "$(_podkop_init_state)" = unknown ]
INIT_OUT='running configuration check failed' INIT_RC=0; [ "$(_podkop_init_state)" = unknown ]
INIT_OUT='' INIT_RC=0; [ "$(_podkop_init_state)" = unknown ]
[ "$(_status_severity unknown 0 fail down tier4)" = unknown ]
[ "$(_status_severity 1 unknown ok up tier1)" = unknown ]
[ "$(_status_severity 1 0 ok up tier1)" = fail ]
echo "PASS: no diagnostic canary leaks across six providers; complete userinfo mask; inconclusive init stays unknown"
CASES
if [ -n "${ASH_TEST_BIN:-}" ]; then
    "$ASH_TEST_BIN" ash "$tmp/cases" "$tmp/functions" "$tmp"
else
    sh "$tmp/cases" "$tmp/functions" "$tmp"
fi
# The only diagnostic attachments must be files made by the tested generators.
grep -Fxq '            if run_internal_diagnostics "$_diag_file" "$_diag_mode" && [ -s "$_diag_file" ]; then' "$bot"
if grep -Eq 'api_document[[:space:]].*(/etc/config|SINGBOX_CONFIG_PATH|podkop_syslog)' "$bot"; then
    echo "raw diagnostic attachment path" >&2
    exit 1
fi
