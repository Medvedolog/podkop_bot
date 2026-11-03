#!/bin/sh
# Forkop 2.0 / Podkop Experimental 0.8.x: readable display, exact tags.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
awk '/^section_display_label\(\) \{/{p=1} /^# _section_selector_tag SECTION/{p=0} p{print}' podkop_bot.sh > "$tmp/labels.sh"
awk '/^_group_selected_human_name\(\) \{/{p=1} /^get_proxy_index_by_tag\(\) \{/{p=0} p{print}' podkop_bot.sh > "$tmp/groups.sh"
sh -n "$tmp/labels.sh"
sh -n "$tmp/groups.sh"
(
  . "$tmp/labels.sh"
  . "$tmp/groups.sh"
  PODKOP_VARIANT=forkop
  PODKOP_UCI=forkop
  _forkop_v2() { [ "$PODKOP_VARIANT" = forkop ]; }
  _podkop_exp_v2() { [ "$PODKOP_VARIANT" = podkop-exp ]; }
  uci() {
    case "$*" in
      '-q get forkop.section_3ebe13.label') printf 'Section #1\n' ;;
      '-q get forkop.tunnel_25dd29.name') printf 'WARP-Tunnel\n' ;;
      '-q get forkop.server_7563a8.label') printf 'Forkop Mixed Proxy\n' ;;
      '-q show forkop') printf 'forkop.section_3ebe13=section\nforkop.section_2afda5=section\n' ;;
      *) printf '' ;;
    esac
  }
  display_proxy_name() {
    case "$1" in
      */*) printf '%s\n' "${1##*/}" ;;
      *': '*) printf '%s\n' "${1#*: }" ;;
      *) printf '%s\n' "$1" ;;
    esac
  }
  test "$(_section_human_label section_3ebe13)" = 'Секция №1'
  test "$(_section_human_label section_2afda5)" = 'Секция №2'
  test "$(_forkop_native_human_label tunnel_25dd29)" = 'WARP-Tunnel'
  test "$(_forkop_native_human_label server_7563a8)" = 'Forkop Mixed Proxy'
  data='{"proxies":{"Group":{"type":"URLTest","now":"Section #1/sub1/🇨🇭 Швейцария"},"Section #1/sub1/🇨🇭 Швейцария":{"type":"VLESS"},"exp":{"type":"URLTest","now":"src1: 🇱🇻 Латвия"},"src1: 🇱🇻 Латвия":{"type":"VLESS"},"empty":{"type":"URLTest"}}}'
  test "$(_group_selected_human_name Group "$data")" = '🇨🇭 Швейцария'
  test -z "$(_group_selected_human_name empty "$data")"
  PODKOP_VARIANT=podkop-exp; PODKOP_UCI=podkop
  test "$(_group_selected_human_name exp "$data")" = '🇱🇻 Латвия'
)
grep -Fq 'human_name="${_group_human} → ${_chosen_human}"' podkop_bot.sh
grep -Fq '_routing_sec_esc=$(html_escape "$(_section_human_label "$_routing_sec")")' podkop_bot.sh
echo 'PASS: Forkop2 services, URLTest selected node and Podkop-exp 0.8 name rendering'
