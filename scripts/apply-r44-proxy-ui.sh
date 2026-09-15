#!/bin/sh
set -eu
f="${1:-podkop_bot.sh}"
[ -f "$f" ] || { echo "missing: $f" >&2; exit 1; }
grep -q '# r44-proxy-ui-sync' "$f" 2>/dev/null && exit 0
tmp="${f}.r44.$$"
awk '
{
  print
  if ($0 ~ /\[ "\$cp" != "Not set" \] && _cp_n=\$\(\(_cp_n \+ 1\)\)/) {
    print "            [ \"$(_warp_rescue_cfg_get enabled 2>/dev/null || true)\" = \"1\" ] && _cp_n=$((_cp_n + 1)) # r44-proxy-ui-sync"
  }
  if ($0 ~ /_wr_lat=\$\(grep '\''\^warp_rescue='\''/) {
    print "                local _wr_ep _wr_node _wr_loc _wr_meta"
    print "                _wr_ep=$(sed -n '\''s/^endpoint=//p'\'' /tmp/podkop_bot/warpscout_rescue.state 2>/dev/null | head -n1)"
    print "                [ -z \"$_wr_ep\" ] && _wr_ep=$(_warp_rescue_cfg_get active_endpoint 2>/dev/null || true)"
    print "                _wr_meta=$(awk -F'\''|'\'' -v e=\"$_wr_ep\" '\''$1==e {print $6 \"|\" $7; exit}'\'' /etc/podkop_bot/warpscout-shortlist.tsv 2>/dev/null)"
    print "                _wr_node=${_wr_meta%%|*}; _wr_loc=${_wr_meta#*|}"
    print "                [ \"$_wr_loc\" = \"$_wr_meta\" ] && _wr_loc=\"\""
  }
  if ($0 ~ /^                    \"\$list_text\" \"\$_row_lbl\" \"\$_wr_port\" \"\$_wr_state\"\)$/) {
    print "                if [ -n \"$_wr_ep\" ]; then"
    print "                    local _wr_desc=\"Сервер выхода: $_wr_ep\""
    print "                    [ -n \"$_wr_loc\" ] && _wr_desc=\"${_wr_desc} · $_wr_loc\""
    print "                    [ -n \"$_wr_node\" ] && _wr_desc=\"${_wr_desc} · $_wr_node\""
    print "                    list_text=$(printf '\''%s\\n<i>%s</i>'\'' \"$list_text\" \"$_wr_desc\")"
    print "                fi"
  }
  if ($0 ~ /^                \"\$E_NET\" \"\$E_PLAY\" \"\$list_text\"\)$/) {
    print "            text=$(printf '\''%s'\'' \"$text\" | sed '\''s/\\\\$//'\'') # r44-proxy-ui-sync"
  }
}
' "$f" > "$tmp"
chmod --reference="$f" "$tmp" 2>/dev/null || chmod +x "$tmp"
mv "$tmp" "$f"
sh -n "$f"
