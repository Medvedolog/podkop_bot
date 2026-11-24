#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
sed -n '/^curl() {/,/^}/p' podkop_bot.sh > "$work/wrapper"
test -s "$work/wrapper"
cat > "$work/curl" <<'MOCK'
#!/bin/sh
printf '%s\n' "$@" > "$TEST_CAPTURE.args"
cat > "$TEST_CAPTURE.stdin"
MOCK
chmod +x "$work/curl"
export PATH="$work:$PATH" TEST_CAPTURE="$work/exec"
. "$work/wrapper"

url='socks5h://review_user%40home:review_pass%3A%2F@127.0.0.1:2080'
curl -s --connect-timeout 3 -x "$url" 'https://example.invalid/' </dev/null
printf '%s\n' '-s' '--connect-timeout' '3' '--config' '-' 'https://example.invalid/' > "$work/expected"
cmp "$work/expected" "$TEST_CAPTURE.args"
printf 'proxy = "%s"\n' "$url" > "$work/expected"
cmp "$work/expected" "$TEST_CAPTURE.stdin"

curl --proxy 'socks5://u:p"\z@127.0.0.1:2080' --data 'x y' </dev/null
printf '%s\n' '--config' '-' '--data' 'x y' > "$work/expected"
cmp "$work/expected" "$TEST_CAPTURE.args"
printf '%s\n' 'proxy = "socks5://u:p\"\\z@127.0.0.1:2080"' > "$work/expected"
cmp "$work/expected" "$TEST_CAPTURE.stdin"

printf '%s\n' 'regular stdin' | curl -x 'socks5h://127.0.0.1:2080' --data-binary @-
printf '%s\n' '-x' 'socks5h://127.0.0.1:2080' '--data-binary' '@-' > "$work/expected"
cmp "$work/expected" "$TEST_CAPTURE.args"
test "$(cat "$TEST_CAPTURE.stdin")" = 'regular stdin'

rm "$TEST_CAPTURE.args"
bad=$(printf '%s\n%s' 'socks5://u:p@127.0.0.1:2080' 'url="https://extra.invalid"')
if curl --proxy "$bad" </dev/null; then exit 1; fi
test ! -e "$TEST_CAPTURE.args"
echo "Proxy credentials only in curl config pipe; arguments and uncredentialed stdin preserved"
