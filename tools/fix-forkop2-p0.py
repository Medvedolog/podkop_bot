#!/usr/bin/env python3
"""One-time, strictly anchored regression repair for Forkop 2 test branch."""
from pathlib import Path

p = Path("podkop_bot.sh")
src = p.read_text()
original = src

def replace_once(old, new, label):
    global src
    count = src.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one anchor, got {count}")
    src = src.replace(old, new, 1)

replace_once(
'''    if _forkop_v2; then
        # The legacy Forkop editor assumes several fields that 2.0 removed.''',
'''    if _forkop_v2; then
        # Forkop 2 URLTest owns independent UCI child sections. Never open
        # Podkop's legacy section-level URLTest editor from the common menu.
        if [ "$cmd" = "urltest_settings" ]; then
            _handle_forkop_ext "fk_ut_menu" "$mid" "" ""
            return
        fi
        # The legacy Forkop editor assumes several fields that 2.0 removed.''',
"forkop2 URLTest routing",
)

replace_once(
'''    forkop_readonly_notice "$1" "section_settings" "Несовместимое поле Forkop 1.x" "Для настройки используйте LuCI Forkop 2.0"''',
'''    forkop_readonly_notice "$1" "section_settings" "Это действие использует устаревшие поля Forkop 1.x" "Для URLTest и подписок откройте отдельные разделы Forkop 2; остальные операции пока выполняйте в LuCI."''',
"misleading readonly notice",
)

# Safely encode the WHOLE group tag, including slash-separated Forkop 2 names.
# Verify group type and exact member before changing runtime state.
anchor = '''    secret=$(uci -q get ${PODKOP_UCI}.settings.yacd_secret_key)'''
replace_once(anchor,
'''    if [ "$method" = "PUT" ] && _forkop_v2; then
        # P0: only exact, verified Selector/Fallback membership may be changed.
        # Do not PUT to URLTest: it selects automatically and has no pinning API.
        local _group _member _snapshot _encoded
        case "$endpoint" in /proxies/*) ;; *) return 1 ;; esac
        _group="${endpoint#/proxies/}"
        # Reject pre-encoded or ambiguous paths rather than double-encoding.
        case "$_group" in ''|*'%'*) return 1 ;; esac
        _member=$(printf '%s' "$data" | jq -er '.name | select(type=="string" and length>0)' 2>/dev/null) || return 1
        _snapshot=$(clash_request /proxies GET 2>/dev/null) || return 1
        printf '%s' "$_snapshot" | jq -e --arg g "$_group" --arg n "$_member" \\
            '.proxies[$g] | select(.type == "Selector" or .type == "Fallback") | (.all // []) | index($n) != null' \\
            >/dev/null 2>&1 || return 1
        _encoded=$(jq -nr --arg group "$_group" '$group | @uri') || return 1
        endpoint="/proxies/${_encoded}"
    fi
''' + anchor,
"clash PUT preflight and full-group encoding",
)

# Preserve installed package version until a separate pre-release is built.
if src == original:
    raise SystemExit("No modifications")
p.write_text(src)
print("Forkop 2 fixes applied", len(original), "->", len(src))
