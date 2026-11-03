#!/bin/sh
# Contract: Forkop 2 Tailscale router identity is a native server, not a tunnel.
set -eu
BOT="${1:-podkop_bot.sh}"
[ -f "$BOT" ] || { echo "Missing bot: $BOT" >&2; exit 1; }
sh -n "$BOT"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT INT TERM
sed -n '/^singbox_supports_tailscale() {/,/^}/p' "$BOT" > "$T/feature.sh"
cat > "$T/ubus" <<'MOCK'
#!/bin/sh
printf '%s\n' "$MOCK_UBUS_JSON"
MOCK
chmod +x "$T/ubus"
export PATH="$T:$PATH"
cat > "$T/check.sh" <<'CHECK'
#!/bin/sh
set -eu
. "$1"
_forkop_v2() { return 0; }
singbox_supports_tailscale
CHECK
chmod +x "$T/check.sh"
MOCK_UBUS_JSON='{"capabilities":{"core":{"known":true,"features":{"tailscale":{"available":true}}}}}'
export MOCK_UBUS_JSON
"$T/check.sh" "$T/feature.sh"
MOCK_UBUS_JSON='{"capabilities":{"core":{"known":true,"features":{"tailscale":{"available":false}}}}}'
export MOCK_UBUS_JSON
if "$T/check.sh" "$T/feature.sh"; then echo "Unsupported core accepted" >&2; exit 1; fi
MOCK_UBUS_JSON='{"capabilities":{"core":{"known":false,"features":{"tailscale":{"available":true}}}}}'
export MOCK_UBUS_JSON
if "$T/check.sh" "$T/feature.sh"; then echo "Unknown core accepted" >&2; exit 1; fi
grep -Fq 'wait_ts_url|wait_ts_hostname|wait_ts_key' "$BOT"
grep -Fq '_ts_management_available()' "$BOT"
grep -Fq 'if _forkop_v2 && _ts_backend_native; then return 0; fi' "$BOT"
grep -Fq 'singbox_supports_tailscale && _ts_management_available' "$BOT"
grep -Fq 'if _forkop_v2 && [ "$_key" != enabled ]; then' "$BOT"
grep -Fq 'tailscale_advertise_exit_node and tailscale_accept_routes keys do not' "$BOT"
grep -Fq '_podkop_exp_v2' "$BOT"
echo "Forkop 2 Tailscale server capability and menu guards OK"
