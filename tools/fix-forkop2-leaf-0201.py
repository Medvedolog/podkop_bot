#!/usr/bin/env python3
"""Forkop2 nested URLTest: show human name when resolver returns a known leaf tag."""
from pathlib import Path
p=Path("podkop_bot.sh")
s=p.read_text()
old='''    _human=$(display_proxy_name "$_leaf")
    [ -n "$_human" ] && [ "$_human" != Unknown ] || return 1
    printf '%s\\n' "$_human"
'''
new='''    _human=$(display_proxy_name "$_leaf")
    # Forkop2 leaves are section/subscription/name tags. If the generic
    # formatter does not know that tag, show the last path component only
    # after _resolve_leaf confirmed it is a real, non-group Clash proxy.
    if { [ -z "$_human" ] || [ "$_human" = Unknown ]; } && _forkop_v2; then
        case "$_leaf" in
            */*) _human=$(printf '%s' "$_leaf" | awk -F/ '{ print $NF }') ;;
        esac
    fi
    [ -n "$_human" ] && [ "$_human" != Unknown ] || return 1
    printf '%s\\n' "$_human"
'''
if s.count(old)!=1: raise SystemExit("nested resolver anchor mismatch: "+str(s.count(old)))
p.write_text(s.replace(old,new,1))
print("Forkop2 nested URLTest final leaf human name implemented")
