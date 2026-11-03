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
sh tools/check-forkop2-render.sh
sh tools/test-dev4-modern-ui.sh
sh tools/test-dev5-human-ui.sh
sh tools/test-forkop2-native-clash.sh
sh tools/test-forkop2-tailscale-native.sh
sh tools/test-forkop2-subs-urltest.sh
sh tools/test-podkop-exp-sources.sh
printf '%s\n' 'Podkop Experimental / Forkop 2 static compatibility guards OK'
