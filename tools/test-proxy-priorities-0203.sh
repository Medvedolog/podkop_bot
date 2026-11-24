#!/bin/sh
# 0.20.3: both engines expose their native priority/fallback model in proxy list.
set -eu
cd "$(dirname "$0")/.."
src=podkop_bot.sh
[ "$#" -eq 0 ] || src="$1"
grep -Fq '"callback_data":"fk_pg_menu"' "$src"
grep -Fq '"callback_data":"xp_menu"' "$src"
grep -Fq '"callback_data":"fkpl_up_' "$src"
grep -Fq '"callback_data":"xp_mu_' "$src"
grep -Fq 'fallback_group' "$src"
grep -Fq '_xp_members()' "$src"
grep -Fq 'К списку прокси' "$src"
grep -Fq 'm3_action*|m3_mixed*' "$src"
# The existing callback dispatcher must still route both handlers.
grep -Fq 'fk_pg_menu|fkpg_*|fkpl_*)' "$src"
grep -Fq 'xp_menu|xp_add_s|xp_add_f' "$src" || grep -Fq 'xp_menu|xp_' "$src"
echo 'PASS: Forkop priority and Podkop primary/fallback entry points'
