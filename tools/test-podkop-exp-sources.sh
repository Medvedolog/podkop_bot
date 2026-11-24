#!/bin/sh
# Podkop Experimental 0.8.8 (config_version 2): sources and section rows the
# bot stages, on a fake uci. No network, no router. Commit/reload is stubbed.
set -eu
cd "$(dirname "$0")/.."
bot=podkop_bot.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fns="_xp_sources _xp_members _xp_member_owned _xp_is_source _xp_source_new_name xp_source_add
xp_source_delete xp_member_add xp_member_words xp_member_move _fk_stage_set _fk_stage_delete
_fk_list_read_any _fk_list_stage_replace_any"
for f in $fns; do
    awk -v f="$f" '$0 ~ "^"f"\\(\\) *\\{" {p=1} p{print} p && /^}/ {exit}' "$bot"
done > "$tmp/lib.sh"
for f in $fns; do grep -q "^$f()" "$tmp/lib.sh" || { echo "FAIL: $f not found" >&2; exit 1; }; done
cat > "$tmp/run.sh" <<'TEST'
. "$1/lib.sh"
UCIDB="$1/db"; PODKOP_UCI=podkop
# Fake uci over "pkg.sec=type" / "pkg.sec.opt='v'" / lists "pkg.sec.opt='a' 'b'".
uci() {
  [ "$1" = -q ] && shift
  case "$1" in
    show) grep -E "^$2([.=]|$)" "$UCIDB" || return 1 ;;
    get) l=$(grep "^$2=" "$UCIDB" | head -1); [ -n "$l" ] || return 1; v=${l#*=}; v=${v#\'}; echo "${v%\'}" ;;
    set) k=${2%%=*}; v=${2#*=}; grep -v "^$k=" "$UCIDB" > "$UCIDB.t" || true; mv "$UCIDB.t" "$UCIDB"
         case "$k" in *.*.*) echo "$k='$v'" >> "$UCIDB" ;; *) echo "$k=$v" >> "$UCIDB" ;; esac ;;
    add_list) k=${2%%=*}; v=${2#*=}; l=$(grep "^$k=" "$UCIDB" | head -1)
         grep -v "^$k=" "$UCIDB" > "$UCIDB.t" || true; mv "$UCIDB.t" "$UCIDB"
         if [ -n "$l" ]; then echo "$l '$v'" >> "$UCIDB"; else echo "$k='$v'" >> "$UCIDB"; fi ;;
    add) n=$(( $(wc -l < "$UCIDB") + 100 )); echo "$2.cfg$n=$3" >> "$UCIDB"; echo "cfg$n" ;;
    delete) grep -v -E "^$2([.=]|$)" "$UCIDB" > "$UCIDB.t" || true; mv "$UCIDB.t" "$UCIDB" ;;
    reorder) k=${2%%=*}; pos=${2#*=}
         awk -v k="$k" -v pos="$pos" -v p="podkop." '
           { split($0, a, "="); key = a[1]; s = key; sub("^" p, "", s); d = index(s, "."); if (d) s = substr(s, 1, d - 1)
             if (!(s in seen)) { seen[s] = 1; ord[++n] = s } lines[s] = lines[s] $0 "\n" }
           END { me = k; sub("^" p, "", me); m = 0
             for (i = 1; i <= n; i++) if (ord[i] != me) rest[++m] = ord[i]
             j = 0; for (i = 1; i <= m + 1; i++) { if (i - 1 == pos) out[i] = me; else out[i] = rest[++j] }
             for (i = 1; i <= m + 1; i++) printf "%s", lines[out[i]] }' "$UCIDB" > "$UCIDB.t"; mv "$UCIDB.t" "$UCIDB" ;;
    *) return 0 ;;
  esac
}
_fk_txn_commit_reload() { return 0; }
fail() { echo "FAIL: $*" >&2; cat "$UCIDB" >&2; exit 1; }
cat > "$UCIDB" <<'X'
podkop.settings=settings
podkop.settings.config_version='2'
podkop.src1=source
podkop.src1.type='subscription'
podkop.src1.label='Provider'
podkop.src1.url='https://sub.example/a'
podkop.main=section
podkop.main.server_choice='balance'
podkop.cure1=cure
podkop.cure1.hash='some-stable-server-hash'
podkop.cure1.kind='record_fragment'
podkop.m1=member
podkop.m1.section='main'
podkop.m1.role='server'
podkop.m1.source='src1'
X
[ "$(_xp_sources)" = "src1|subscription|Provider|https://sub.example/a|0|auto" ] || fail "sources: $(_xp_sources)"
name=$(xp_source_add links 'vless://u@h:443#NL' 'NL') || fail "links add"
[ "$name" = src2 ] || fail "new source name $name"
[ "$(uci get podkop.src2.type)" = links ] || fail "links type"
xp_member_add main fallback src2 || fail "fallback row"
xp_member_add main fallback direct || fail "direct fallback"
if xp_member_add main server direct; then fail "direct as a server row"; fi
if xp_member_add main server nosuch; then fail "row of a missing source"; fi
rows=$(_xp_members main | cut -d'|' -f2,3 | tr '\n' ' ')
[ "$rows" = "server|src1 fallback|src2 fallback|direct " ] || fail "rows: $rows"
f2=$(_xp_members main | awk -F'|' '$3 == "direct" { print $1 }')
xp_member_move "$f2" main up || fail "move"
rows=$(_xp_members main | cut -d'|' -f3 | tr '\n' ' ')
[ "$rows" = "src1 direct src2 " ] || fail "after move: $rows"
xp_member_words m1 main include 'DE, NL' || fail "include words"
[ "$(_xp_members main | awk -F'|' '$1 == "m1" { print $4 }')" = "DE, NL" ] || fail "include list"
xp_member_words m1 main include '-' || fail "clear words"
[ -z "$(_xp_members main | awk -F'|' '$1 == "m1" { print $4 }')" ] || fail "include cleared"
if xp_member_words m1 other include 'x'; then fail "row of another section"; fi
xp_source_delete src2 || fail "source delete"
! grep -q "source='src2'" "$UCIDB" || fail "rows of the deleted source left"
! grep -q '^podkop.src2' "$UCIDB" || fail "source left"
[ "$(uci get podkop.main.server_choice)" = balance ] || fail "0.8.13 choice was modified"
[ "$(uci get podkop.cure1)" = cure ] || fail "0.8.13 per-server cure removed"
[ "$(uci get podkop.cure1.kind)" = record_fragment ] || fail "0.8.13 cure was changed"
TEST
sh "$tmp/run.sh" "$tmp"
echo "Podkop Experimental sources and section rows: OK"
