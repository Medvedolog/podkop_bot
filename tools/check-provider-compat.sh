#!/bin/sh
# Static compatibility contract: no OpenWrt device or WAN access required.
set -eu
cd "$(dirname "$0")/.."
sh -n install.sh
sh -n podkop_bot.sh
for needle in 'podkop-exp)' '_pkg_has podkop-exp' 'podkop-exp embeds sing-box' 'Forkop 2 moves Mixed Proxy'; do
    grep -Fq "$needle" install.sh || { echo "Missing installer contract: $needle" >&2; exit 1; }
done
for needle in '_forkop_v2()' '_forkop_mixed_server()' '_mixed_port_for_section()' 'podkop-net/podkop-experimental' '_forkop_v2_ui_guard' 'Podkop Experimental: обновление через SSH'; do
    grep -Fq "$needle" podkop_bot.sh || { echo "Missing bot contract: $needle" >&2; exit 1; }
done
printf '%s\n' 'Podkop Experimental / Forkop 2 static compatibility guards OK'
