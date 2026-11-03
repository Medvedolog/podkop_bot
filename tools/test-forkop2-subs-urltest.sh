#!/bin/sh
# Forkop 2 subscriptions and URLTest groups: the UCI the bot stages, on a fake
# uci. No network, no router. Commit/reload and Clash API are stubbed.
set -eu
cd "$(dirname "$0")/.."
bot=podkop_bot.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fns="fk2_sub_add fk2_child_delete fk2_ut_add fk2_ut_filter_set _fk2_filter_value fk2_sub_refresh
_fk2_sub_tag_next _fk2_child_names _fk_stage_set _fk_stage_delete _fk_child_owned _fk_child_type
_fk_list_read_any forkop_children_by_type_and_owner forkop_subscription_children section_clash_tag
forkop_v2 _country_flag _pct_encode"
for f in $fns; do
    awk -v f="$f" '$0 ~ "^"f"\\(\\) *\\{" {p=1} p{print} p && /^}/ {exit}' "$bot"
done > "$tmp/lib.sh"
for f in $fns; do grep -q "^$f()" "$tmp/lib.sh" || { echo "FAIL: $f not found" >&2; exit 1; }; done
cat > "$tmp/run.sh" <<'TEST'
. "$1/lib.sh"
UCIDB="$1/db"; PODKOP_UCI=forkop; PODKOP_VARIANT=forkop
uci() {
  [ "$1" = -q ] && shift
  case "$1" in
    show) grep -E "^$2([.=]|$)" "$UCIDB" ;;
    get) l=$(grep "^$2=" "$UCIDB" | head -1); [ -n "$l" ] || return 1; v=${l#*=}; v=${v#\'}; echo "${v%\'}" ;;
    set) k=${2%%=*}; v=${2#*=}; grep -v "^$k=" "$UCIDB" > "$UCIDB.t" || true; mv "$UCIDB.t" "$UCIDB"
         case "$k" in *.*.*) echo "$k='$v'" >> "$UCIDB" ;; *) echo "$k=$v" >> "$UCIDB" ;; esac ;;
    add) n=$(( $(wc -l < "$UCIDB") + 100 )); echo "$2.cfg$n=$3" >> "$UCIDB"; echo "cfg$n" ;;
    delete) grep -v -E "^$2([.=]|$)" "$UCIDB" > "$UCIDB.t" || true; mv "$UCIDB.t" "$UCIDB" ;;
    *) return 0 ;;
  esac
}
_fk_txn_commit_reload() { return 0; }
CLASH_LOG="$1/clash"; : > "$CLASH_LOG"
clash_request() { printf '%s %s\n' "$2" "$1" >> "$CLASH_LOG"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
cat > "$UCIDB" <<'X'
forkop.settings=settings
forkop.settings.config_version='2.0.0'
forkop.main=section
forkop.main.label='Main'
forkop.s1=subscription_url
forkop.s1.section='main'
forkop.s1.url='https://sub.example/a'
forkop.s1.tag='sub1'
X
fk2_sub_add main 'https://sub.example/b' || fail "sub add"
new=$(grep '=subscription_url$' "$UCIDB" | grep -v '^forkop.s1=' | sed 's/^forkop\.\(.*\)=.*/\1/')
[ "$(uci get forkop.$new.tag)" = sub2 ] || fail "second subscription tag"
[ "$(uci get forkop.$new.section)" = main ] || fail "subscription owner"
[ "$(uci get forkop.$new.subscription_update_interval)" = 1h ] || fail "update interval"
[ "$(fk2_sub_refresh main)" = "2 0" ] || fail "refresh count"
grep -qx 'PUT /providers/proxies/Main%2Fsub1' "$CLASH_LOG" || fail "provider path"
fk2_ut_add main 'Fastest' || fail "urltest add"
ut=$(grep '=urltest$' "$UCIDB" | sed 's/^forkop\.\(.*\)=.*/\1/')
[ "$(uci get forkop.$ut.server_filter_mode)" = all ] || fail "urltest mode"
fk2_ut_filter_set "$ut" main inc "$(_fk2_filter_value 'de nl')" || fail "filter inc"
[ "$(uci get forkop.$ut.server_filter_mode)" = include ] || fail "include mode"
[ "$(uci get forkop.$ut.include_regex)" = "$(printf '(?:\360\237\207\251\360\237\207\252)|(?:\360\237\207\263\360\237\207\261)')" ] || fail "flag regex"
fk2_ut_filter_set "$ut" main inc "" && fk2_ut_filter_set "$ut" main exc 'x' || fail "filter exc"
[ "$(uci get forkop.$ut.server_filter_mode)" = exclude ] || fail "exclude mode"
fk2_ut_filter_set "$ut" main exc "" || fail "filter clear"
[ "$(uci get forkop.$ut.server_filter_mode)" = all ] || fail "all mode"
if fk2_child_delete "$ut" urltest other; then fail "deleted a child of another section"; fi
fk2_child_delete s1 subscription_url main || fail "sub delete"
! grep -q '^forkop.s1' "$UCIDB" || fail "subscription still present"
TEST
sh "$tmp/run.sh" "$tmp"
echo "Forkop 2 subscriptions and URLTest groups: OK"
