#!/bin/sh
# Read-only regression for a real-world Forkop2 two-mixed-server UCI layout.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT HUP INT TERM
for f in fk2_mixed_servers fk2_section_mixed sec_mixed_enabled sec_mixed_port; do
  awk -v f="$f" '$0 ~ "^"f"\\(\\) *\\{" {p=1} p{print} p && /^}/ {exit}' podkop_bot.sh >>"$tmp/lib.sh"
done
sh -n "$tmp/lib.sh"
cat >"$tmp/db" <<'EOF'
forkop.settings=settings
forkop.settings.config_version='2.0.0'
forkop.section_3ebe13=section
forkop.section_3ebe13.label='Section #1'
forkop.section_2afda5=section
forkop.section_2afda5.label='WARP'
forkop.server_7563a8=server
forkop.server_7563a8.protocol='mixed'
forkop.server_7563a8.routing_mode='section'
forkop.server_7563a8.routing_section='section_3ebe13'
forkop.server_7563a8.listen_port='2080'
forkop.server_7563a8.enabled='1'
forkop.server_b1db54=server
forkop.server_b1db54.protocol='mixed'
forkop.server_b1db54.routing_mode='section'
forkop.server_b1db54.routing_section='section_2afda5'
forkop.server_b1db54.listen_port='2081'
forkop.server_b1db54.enabled='1'
forkop.tunnel_25dd29=tunnel
forkop.tunnel_25dd29.kind='warp'
EOF
(
  . "$tmp/lib.sh"
  PODKOP_UCI=forkop
  uci() {
    [ "$1" = -q ] && shift
    case "$1" in
      show) cat "$tmp/db" ;;
      get) sed -n "s/^$2='\\(.*\\)'$/\\1/p" "$tmp/db" | head -1 ;;
      *) echo "Unexpected mutating UCI operation" >&2; return 1 ;;
    esac
  }
  forkop_v2() { return 0; }
  [ "$(fk2_section_mixed section_3ebe13 | cut -d'|' -f1)" = server_7563a8 ]
  [ "$(fk2_section_mixed section_2afda5 | cut -d'|' -f1)" = server_b1db54 ]
  [ "$(sec_mixed_enabled section_3ebe13)" = 1 ]
  [ "$(sec_mixed_port section_3ebe13)" = 2080 ]
  [ "$(sec_mixed_port section_2afda5)" = 2081 ]
  [ -z "$(fk2_section_mixed missing)" ]
  sed -i "s/forkop.server_b1db54.enabled='1'/forkop.server_b1db54.enabled='0'/" "$tmp/db"
  [ "$(sec_mixed_enabled section_2afda5)" = 0 ]
)
grep -Fq 'Mixed UCI сервер:' podkop_bot.sh
grep -Fq '_fk_txn_commit_reload || _mixed_rc=$?' podkop_bot.sh
echo 'Forkop2 Mixed 2080/2081 mapping and fail-safe write path: OK'
