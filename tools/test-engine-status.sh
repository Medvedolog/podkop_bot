#!/bin/sh
# Read-only fixture tests. Do not source the bot or start its Telegram loop.
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
BOT=podkop_bot.sh
{
    sed -n '/^_engine_procd() {/,/^# Supports --engine-status-json (read-only)/p' "$BOT"
    sed -n '/^do_podkop_stop() {/,/^}/p' "$BOT"
    sed -n '/^_status_severity() {/,/^}/p' "$BOT"
    sed -n '/^_url_encode_cred() {/,/^}/p' "$BOT"
    sed -n '/^_mixed_proxy_auth() {/,/^}/p' "$BOT"
    sed -n '/^get_singbox_version_display() {/,/^}/p' "$BOT"
} >"$work/functions"
sed -n '/# Check B: sing-box process liveness/,/# Check C: SOCKS upstream/p' "$BOT" >"$work/watchdog"

cat >"$work/cases" <<'CASES'
set -eu
. "$1"
trace="$2/trace"
OWNER='{"podkop":{"instances":{"main":{"running":true,"pid":4312,"command":["/usr/bin/podkop","daemon"]}}}}'
CORE='{"sing-box":{"instances":{"sing-box.main":{"running":true,"pid":502,"command":["/usr/bin/sing-box","run","-c","/tmp/sing-box/config.json"]}}}}'
STANDBY='{"podkop":{"instances":{"main":{"running":false,"command":["/usr/bin/podkop","daemon"]}}}}'
GO_STATS='{"running":true,"at":239,"down":9,"up":3,"connections":1,"memory":32768}'
WRAPPED='{"code":0,"stdout":"{\"running\":1,\"enabled\":0}"}'
EXPECTED=podkop
STOPPING=0
ubus() {
    case "$*" in
        '-t 2 call service list {"name":"podkop"}')
            [ "$EXPECTED" = podkop ] || { echo wrong-service >>"$trace"; return 1; }
            [ "$STOPPING" = 0 ] || { printf '{}\n'; return; }
            [ "${SERVICE_FAIL:-0}" = 0 ] || return 1
            printf '%s\n' "$SERVICE" ;;
        '-t 2 call service list {"name":"sing-box"}')
            [ "$EXPECTED" = sing-box ] || { echo wrong-service >>"$trace"; return 1; }
            printf '%s\n' "$SERVICE" ;;
        '-t 2 call podkop stats {}')
            [ "$EXPECTED" = podkop ] || { echo wrong-stats >>"$trace"; return 1; }
            [ "${STATS_FAIL:-0}" = 0 ] || return 1
            printf '%s\n' "$STATS" ;;
        '-t 2 call podkop run {"command":"get_sing_box_status","params":[]}')
            [ "$EXPECTED" = podkop ] || { echo wrong-wrapped >>"$trace"; return 1; }
            printf '%s\n' "$WRAP" ;;
        *) echo unexpected-ubus >>"$trace"; return 1 ;;
    esac
}
curl() {
    [ "$*" = "-q --noproxy * -fsS --connect-timeout 1 --max-time 2 --unix-socket /var/run/podkop/ctl.sock http://localhost/status" ] ||
        { echo unexpected-curl >>"$trace"; return 1; }
    [ -n "${SOCKET:-}" ] || return 1
    printf '%s\n' "$SOCKET"
}
pidof() { echo forbidden-pidof >>"$trace"; return 1; }
pgrep() { echo forbidden-pgrep >>"$trace"; return 1; }
kill() { echo forbidden-kill >>"$trace"; return 1; }
forkop_v2() { return 1; }
uci() {
    case "$*" in
        '-q get podkop.main.mixed_proxy_username') printf '%s\n' 'a@b' ;;
        '-q get podkop.main.mixed_proxy_password') printf '%s\n' 'x:/#' ;;
        *) return 1 ;;
    esac
}
init_fixture() {
    [ "$*" = stop ] || return 1
    STOPPING=1
    echo selected-stop >>"$trace"
}
check() {
    _engine_status_json | jq -e --arg state "$1" --arg pid "$2" --arg process "$3" --arg service "$EXPECTED" \
        '.state == $state and (.pid | tostring) == $pid and .process_state == $process and .service == $service' >/dev/null
    echo "$4"
}
PODKOP_VARIANT=podkop-exp PODKOP_UCI=podkop
SERVICE="$OWNER" STATS="$GO_STATS" WRAP='{}'
check running 4312 running 'embedded 0.8.21 ready with no external process'
STATS='{"running":false}'
check stopped 4312 running 'embedded daemon exists but dataplane not ready'
STATS='{"running":"true"}'
check unknown 4312 running 'malformed stats are not interpreted as a stopped tunnel'
STATS_FAIL=1 SOCKET='{"running":true}'
check running 4312 running 'local Unix status confirms running when stats unavailable'
SOCKET='{"running":false}'
check stopped 4312 running 'local Unix status structurally confirms stopped'
SOCKET='' WRAP="$WRAPPED"
check running 4312 running 'older Experimental wrapped status fallback'
WRAP='{"code":0,"stdout":"{\"running\":0,\"enabled\":0}"}'
check unknown 4312 running 'old wrapped false is ambiguous when the daemon is alive'
WRAP='{"code":1,"stdout":"{\"running\":0}"}'
check unknown 4312 running 'failed wrapped command remains unknown'
SERVICE_FAIL=1
check unknown null unknown 'unavailable procd remains unknown'
SERVICE_FAIL=0 SERVICE="$STANDBY"
check stopped null stopped 'procd reports Experimental stopped'
SERVICE='{}'
check stopped null stopped 'absent Experimental: no fallback to unrelated sing-box'
SERVICE='{"sing-box":{"instances":{}}}'
check unknown null unknown 'unexpected or unscoped procd reply is not authoritative'
SERVICE='{"podkop":{"instances":{"main":{"running":true,"pid":4312,"command":["/usr/bin/podkop","show_version"]}}}}'
check unknown null unknown 'diagnostic command cannot stand in for Exp daemon'
[ "$(_status_severity 1 unknown ok up tier1)" = unknown ]
[ "$(_status_severity 1 0 ok up tier1)" = fail ]
[ "$(_mixed_proxy_auth main)" = a%40b:x%3A%2F%23@ ]
echo 'unknown status and Experimental 0.8.21 Mixed auth'
PODKOP_INIT=init_fixture SERVICE="$OWNER"
do_podkop_stop
[ "$(cat "$trace")" = selected-stop ]
echo 'stop invokes only the selected service, never PID signaling'
EXPECTED=sing-box PODKOP_VARIANT=original SERVICE="$CORE"
check running 502 running 'standalone Podkop Engine uses sing-box procd owner'
# Forkop 2.0.0 installs sing-box-forkop 1.14.4-r1. Its init opens
# the default procd instance, unlike Podkop Engine's named sing-box.main.
PODKOP_VARIANT=forkop
SERVICE='{"sing-box":{"instances":{"instance1":{"running":true,"pid":504,"command":["/usr/bin/sing-box","run","-c","/etc/sing-box/config.json","-D","/usr/share/sing-box","--disable-color"]}}}}'
check running 504 running 'Forkop 2.0.0 official core: unnamed procd instance, sing-box run'
SERVICE='{"sing-box":{"instances":{"main":{"running":true,"pid":502,"command":["/usr/bin/sing-box","version"]}}}}'
check unknown null unknown 'unrelated command under named service is unknown'
SERVICE='{"sing-box":{"instances":{"main":{"running":true,"pid":502,"command":["/usr/bin/sing-box","run"]},"another":{"running":true,"pid":503,"command":["/usr/bin/sing-box","run"]}}}}'
check unknown null unknown 'multiple core instances are ambiguous'
SERVICE='{"sing-box":{"instances":{"main":{"running":false}}}}'
check stopped null stopped 'standalone stopped'
[ "$(cat "$trace")" = selected-stop ]

# Exercise the shipped watchdog transition block, not a mirrored state machine.
# Unknown data must preserve the last confirmed state/PID and not manufacture
# a route reset, recovery, flap alert, or second consecutive stopped sample.
ROUTE_CMD_FILE="$2/route" last_sb_state=running last_sb_pid=4312
_sb_stopped_streak=0 _sb_stop_alerted=0 _sbf_flapping=0
_lk_send=1 _lk_legacy=0 _lam=smart last_leaf='' _hn=fixture E_ERR='' E_OK='' ADMIN_ID=1
logger() { :; }
display_proxy_name() { printf '%s' "$1"; }
html_escape() { printf '%s' "$1"; }
alert_file="$2/alerts"
send_health_alert() { printf 'alert\n' >>"$alert_file"; }
route_step() {
    local curr_sb_state="$1" curr_sb_pid="${2:-}"
    . "$watchdog"
    return 0
}
watchdog="$2/watchdog"
route_step unknown
[ "$last_sb_state" = running ] && [ "$last_sb_pid" = 4312 ] && [ ! -e "$ROUTE_CMD_FILE" ] || exit 1
route_step stopped
[ "$_sb_stopped_streak" = 1 ] && [ "$(cat "$ROUTE_CMD_FILE")" = down ] || exit 1
route_step unknown
[ "$_sb_stopped_streak" = 0 ] && [ "$last_sb_state" = stopped ] || exit 1
route_step stopped
[ "$_sb_stopped_streak" = 1 ] && [ "$_sb_stop_alerted" = 0 ] && [ ! -e "$alert_file" ] || exit 1
route_step stopped
[ "$_sb_stopped_streak" = 2 ] && [ "$_sb_stop_alerted" = 1 ] && [ "$(wc -l <"$alert_file")" = 1 ] || exit 1
route_step unknown
[ "$last_sb_state" = stopped ] && [ "$(wc -l <"$alert_file")" = 1 ] || exit 1
route_step running 4377
[ "$last_sb_pid" = 4377 ] && [ "$(cat "$ROUTE_CMD_FILE")" = up ] && [ "$(wc -l <"$alert_file")" = 2 ] || exit 1
echo 'watchdog unknown preserves confirmed state, and interrupts stopped streak'

BOT_DIR="$2" SB_VER_CACHE="$2/version.cache"
opkg() {
    [ "$*" = list-installed ] || return 1
    printf '%s\n' 'sing-box - 1.12.1-r1' 'podkop-engine-full - 1.14.4-r28'
}
mkdir -p "$2/bin"
cat > "$2/bin/sing-box" <<'FORBIDDEN'
#!/bin/sh
echo forbidden-singbox >> "$ENGINE_TEST_TRACE"
exit 1
FORBIDDEN
chmod +x "$2/bin/sing-box"
export ENGINE_TEST_TRACE="$trace" PATH="$2/bin:$PATH"
_engine_exp_call() {
    [ "$1" = get_system_info ] || return 1
    printf '%s\n' '{"sing_box_version":"1.14.4","engine":"sing-box 1.14.4, podkop-engine r28, slim"}'
}
PODKOP_VARIANT=original
if ver=$(get_singbox_version_display); then
    [ "$ver" = '1.14.4-r28 · Podkop Engine Full' ]
else
    exit 1
fi
PODKOP_VARIANT=podkop-exp
[ "$(get_singbox_version_display)" = 'sing-box 1.14.4, podkop-engine r28, slim' ]
[ "$(cat "$trace")" = selected-stop ]
echo 'engine versions are sourced without spawning sing-box'
CASES

if [ -n "${ASH_TEST_BIN:-}" ]; then
    "$ASH_TEST_BIN" ash "$work/cases" "$work/functions" "$work"
else
    sh "$work/cases" "$work/functions" "$work"
fi
# Guard against reintroducing global PID matching anywhere in the shipped bot.
! grep -Eq '(pidof|pgrep)([[:space:]]+-[^[:space:]]+)*[[:space:]]+"?sing-box([[:space:]"$]|$)' "$BOT"
# The exported status probe must exit before network, state files or daemon startup.
line=$(grep -nFx '# Supports --engine-status-json (read-only)' "$BOT" | cut -d: -f1)
first_mkdir=$(grep -nF 'mkdir -p "$BOT_DIR"' "$BOT" | head -n 1 | cut -d: -f1)
[ "$line" -lt "$first_mkdir" ]
