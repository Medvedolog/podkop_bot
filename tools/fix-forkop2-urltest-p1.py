#!/usr/bin/env python3
"""Forkop 2.0 URLTest regression fix; target is experimental podkop_bot.sh only."""
from pathlib import Path

p=Path("podkop_bot.sh")
s=p.read_text()
def edit(old,new,label):
    global s
    n=s.count(old)
    if n != 1: raise SystemExit(f"{label}: expected exactly one match, found {n}")
    s=s.replace(old,new,1)

# Old callbacks may survive across bot updates. Route both into native Forkop 2 URLTest pages.
edit(
'''        if [ "$cmd" = "urltest_settings" ]; then
            _handle_forkop_ext "fk_ut_menu" "$mid" "" ""
            return
        fi''',
'''        case "$cmd" in
            urltest_settings|urltest_filters_menu)
                _handle_forkop_ext "fk_ut_menu" "$mid" "" ""
                return ;;
        esac''',
"route old filter callbacks"
)
# Preserve Forkop 2 explicit filter mode. Hidden/inactive include_outbounds
# must not accidentally flip an exclude-only filter to include when editing exclusions.
edit(
'''    _fk_child_owned "$_ch" urltest "$_sec" || return 1
    [ "$_side" = inc ] && _key=include_regex || _key=exclude_regex
    if [ -n "$_val" ]; then''',
'''    _fk_child_owned "$_ch" urltest "$_sec" || return 1
    local _current_mode
    _current_mode=$(uci -q get "${PODKOP_UCI}.${_ch}.server_filter_mode" 2>/dev/null)
    case "$_current_mode" in all|include|exclude|'') ;; *) return 1 ;; esac
    case "$_side" in
        inc) _key=include_regex ;;
        exc) _key=exclude_regex ;;
        *) return 1 ;;
    esac
    if [ -n "$_val" ]; then''',
"check filter side and current mode"
)
edit(
'''    if [ -n "$_inc" ]; then _mode=include; elif [ -n "$_exc" ]; then _mode=exclude; else _mode=all; fi
    _fk_stage_set "${PODKOP_UCI}.${_ch}.server_filter_mode" "$_mode" || return 1''',
'''    if [ "$_side" = inc ] && [ -n "$_inc" ]; then
        # Explicit include action selects include mode.
        _mode=include
    elif [ "$_side" = exc ] && [ "$_current_mode" = include ] && [ -n "$_inc" ]; then
        # Preserve active include mode while editing its exclusions.
        _mode=include
    elif [ -n "$_exc" ]; then
        # Do NOT activate a latent, unused include_outbounds list from LuCI.
        _mode=exclude
    elif [ "$_current_mode" = include ] && [ -n "$_inc" ]; then
        _mode=include
    else
        _mode=all
    fi
    _fk_stage_set "${PODKOP_UCI}.${_ch}.server_filter_mode" "$_mode" || return 1''',
"preserve filter mode"
)
p.write_text(s)
print("Forkop2 URLTest fix applied")
