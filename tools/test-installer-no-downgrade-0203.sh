#!/bin/sh
# Version-aware installer regression: no live installation/network.
set -eu
cd "$(dirname "$0")/.."
src=install.sh
[ "$#" -eq 0 ] || src="$1"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT HUP INT TERM
sed -n '/^_inst_version_newer(){/,/^}/p' "$src" > "$tmp"
[ -s "$tmp" ]
sh -n "$tmp"
. "$tmp"
_inst_version_newer 0.20.3-dev3 0.20.2
_inst_version_newer 0.20.3 0.20.3-dev3
_inst_version_newer 0.20.3-dev4 0.20.3-dev3
if _inst_version_newer 0.20.3-dev3 0.20.3; then exit 1; fi
if _inst_version_newer 0.20.3-dev3 0.20.3-dev4; then exit 1; fi
if _inst_version_newer 0.20.3 0.20.3; then exit 1; fi
if _inst_version_newer 0.20.2 0.20.3-dev3; then exit 1; fi
if _inst_version_newer unknown 0.20.2; then exit 1; fi
grep -Fq '_inst_version_newer "$INSTALLED_VER" "$REMOTE_VER"' "$src"
echo 'PASS installer no-downgrade protection for dev/stable versions'
