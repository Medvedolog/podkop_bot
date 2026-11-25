#!/bin/sh
# 0.20.3 Podkop Experimental 0.8.23 native UCI surface regression.
set -eu
cd "$(dirname "$0")/.."
src=podkop_bot.sh
[ "$#" -eq 0 ] || src="$1"
grep -Fq '_xp_0823()' "$src"
grep -Fq 'fallback_choice' "$src"
for val in order fastest loss balance; do
  grep -Fq "xp_fc_$val" "$src"
done
grep -Fq 'xp_member_protocols()' "$src"
grep -Fq '.protocols' "$src"
grep -Fq 'wait_xp_mp_' "$src"
grep -Fq 'xp_mp_*)' "$src"
grep -Fq '_fk_list_stage_replace_any' "$src"
grep -Fq '_fk_txn_commit_reload' "$src"
grep -Fq 'vless|vmess|trojan|shadowsocks|hysteria2' "$src"
echo 'PASS: 0.8.23 guarded fallback strategies and member protocol filters'
