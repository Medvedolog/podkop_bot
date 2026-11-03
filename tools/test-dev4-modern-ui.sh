#!/bin/sh
# Source-level regression: Forkop2 runtime tags + Podkop Experimental source names.
set -eu
cd "$(dirname "$0")/.."
bot=podkop_bot.sh
sh -n "$bot"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
awk '/^_utf8_awk_body=/{p=1} /^html_escape\(\) \{/{p=0} p{print}' "$bot" > "$tmp/utf8.sh"
awk '/^section_display_label\(\) \{/{p=1} /^get_active_proxy_name\(\) \{/{p=0} p{print}' "$bot" > "$tmp/selector.sh"
awk '/^_modern_proxy_display_tag\(\) \{/{p=1} /^extract_server_port_from_uri\(\) \{/{p=0} p{print}' "$bot" > "$tmp/display.sh"
(
. "$tmp/utf8.sh"; . "$tmp/selector.sh"; . "$tmp/display.sh"
PODKOP_VARIANT=forkop; PODKOP_UCI=forkop
get_active_section(){ echo 'section_3ebe13'; }
_forkop_v2(){ [ "$PODKOP_VARIANT" = forkop ]; }
_podkop_exp_v2(){ [ "$PODKOP_VARIANT" = podkop-exp ]; }
uci(){ case "$*" in
'-q get forkop.section_3ebe13.label') echo 'Section #1' ;;
'-q get podkop.section_3ebe13.label') echo 'Главная' ;;
'-q get podkop.src1'|'-q get podkop.src2') echo source ;;
'-q get podkop.src2.label') echo 'Ручной VLESS' ;;
*) return 1 ;;
esac; }
get_proxy_human_name_by_tag(){ :; }
build_tag_name_cache(){ :; }
build_tag_uri_cache(){ :; }
get_uri_by_tag(){ :; }
TAG_NAME_CACHE="$tmp/no-tags"; TAG_URI_CACHE="$tmp/no-links"
[ "$(display_proxy_name 'Section #1/sub1/🇩🇪 Германия')" = '🇩🇪 Германия' ]
[ "$(display_proxy_name 'Section #1/sub2/🇩🇪 Германия')" = '🇩🇪 Германия' ]
[ "$(display_proxy_name 'Section #1/URLTest')" = URLTest ]
[ "$(display_proxy_name_with_tag 'Section #1/sub1/🇩🇪 Германия')" = '🇩🇪 Германия' ]
long='🇩🇪 Германия и Нидерланды — 12345'
short=$(_proxy_button_name "$long" 15)
[ "$(_utf8_len "$short")" -le 15 ]
case "$short" in *'…') : ;; *) exit 1 ;; esac
PODKOP_VARIANT=podkop-exp; PODKOP_UCI=podkop
[ "$(display_proxy_name 'src1: 🇳🇱 Нидерланды')" = '🇳🇱 Нидерланды' ]
[ "$(display_proxy_name 'src2')" = 'Ручной VLESS' ]
[ "$(display_proxy_name 'section_3ebe13-out')" = 'Главная' ]
[ "$(display_proxy_name 'section_3ebe13-urltest')" = 'Автовыбор (URLTest)' ]
[ "$(display_proxy_name 'section_3ebe13-fallback-2')" = 'Резерв №2' ]
)
echo 'PASS dev4 modern display labels'
