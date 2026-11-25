#!/bin/sh
# Portable POSIX shell IPv6 and CIDR validation, including compressed syntax.
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT HUP INT TERM
sed -n '/^_m3x_ipv4() {/,/^_m3x_valid() {/p' podkop_bot.sh | sed '$d' > "$tmp"
sh -n "$tmp"
. "$tmp"
for v in 0.0.0.0 192.0.2.1 255.255.255.255 '::' '::1' 2001:db8::1 \
    2001:db8:0:0:0:0:0:1 2001:db8:0000:0000:0000:0000:0000:0001 \
    ::ffff:192.0.2.1; do
    _m3x_ip "$v" || { echo "valid rejected: $v" >&2; exit 1; }
done
for v in '999.1.2.3' '1.2.3' '1.2.3.999' '2001:db8:::1' '2001:db8::1::2' \
    '2001:db8:0:0:0:0:0:1:2' '2001:db8:gggg::1' '1:2:3:4:5:6:7' \
    'abcd:ef' '2001:db8:' ':2001:db8:1:2:3:4:5:6' '::ffff:192.0.2.999' \
    '0:0:0:0:0:0:0:0:0' '' '::::'; do
    if _m3x_ip "$v"; then echo "invalid accepted: $v" >&2; exit 1; fi
done
for v in 192.0.2.0/24 0.0.0.0/0 2001:db8::/32 ::/0 ::1/128; do
    _m3x_ip_or_cidr "$v" || { echo "CIDR rejected: $v" >&2; exit 1; }
done
for v in 192.0.2.0/33 2001:db8::/129 192.0.2.0/a '::/1;reboot' '::/1/2' \
    192.0.2.999/24; do
    if _m3x_ip_or_cidr "$v"; then echo "CIDR invalid accepted: $v" >&2; exit 1; fi
done
echo 'PASS IPv4, IPv6 compressed and IPv4-mapped, CIDR prefix boundaries'
