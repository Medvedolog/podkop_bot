#!/bin/sh
# Test nested Forkop2 group → leaf name resolution without network or UCI writes.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
awk '/^_group_selected_human_name\(\) \{/{p=1} p{print} p && /^}/ {exit}' podkop_bot.sh >"$tmp/human.sh"
sh -n "$tmp/human.sh"
(
 . "$tmp/human.sh"
 _resolve_leaf() { printf '%s\n' 'Section #1/sub1/🇷🇺 Россия'; }
 display_proxy_name() { printf '%s\n' Unknown; }
 _forkop_v2() { return 0; }
 proxies='{"proxies":{"Section #1/sub1/🇷🇺 Россия":{"type":"VLESS"}}}'
 got=$(_group_selected_human_name 'Section #1/URLTest #1' "$proxies")
 [ "$got" = '🇷🇺 Россия' ]
 proxies='{"proxies":{"Section #1/sub1/🇷🇺 Россия":{"type":"URLTest"}}}'
 if _group_selected_human_name 'Section #1/URLTest #1' "$proxies" >/dev/null; then exit 1; fi
 _forkop_v2() { return 1; }
 proxies='{"proxies":{"Section #1/sub1/🇷🇺 Россия":{"type":"VLESS"}}}'
 if _group_selected_human_name 'Section #1/URLTest #1' "$proxies" >/dev/null; then exit 1; fi
)
echo 'Forkop2 nested URLTest leaf labels and group rejection: OK'
