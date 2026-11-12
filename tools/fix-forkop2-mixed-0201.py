#!/usr/bin/env python3
"""Make Forkop2 Mixed Proxy changes transactional, and show exact routed UCI server."""
from pathlib import Path
p=Path("podkop_bot.sh")
s=p.read_text()
def once(old,new,label):
    global s
    n=s.count(old)
    if n!=1: raise SystemExit(f"{label}: expected 1 anchor, found {n}")
    s=s.replace(old,new,1)
once(
'''        "do_toggle_mixed")
            # Off, or on with a free port when none is set; on Forkop 2 the mixed
            # proxy is a server routed to the section (see sec_mixed_toggle).
            sec_mixed_toggle "$sec"
            uci_commit_safe "\${PODKOP_UCI}"
''',
'''        "do_toggle_mixed")
            # Forkop 2 mixes are standalone UCI server objects; never use the
            # legacy direct commit + reload path, which leaves failed changes
            # committed even if the dataplane cannot start.
            if forkop_v2; then
                local _mixed_rc=0
                sec_mixed_toggle "$sec" || _mixed_rc=$?
                if [ "$_mixed_rc" -eq 0 ]; then
                    _fk_txn_commit_reload || _mixed_rc=$?
                else
                    uci -q revert "\${PODKOP_UCI}" 2>/dev/null || true
                fi
                if [ "$_mixed_rc" -eq 0 ]; then
                    _handle_settings "section_settings" "$mid" "" ""
                else
                    _fk_txn_report "$_mixed_rc" "$mid" "section_settings"
                fi
                return
            fi
            # Legacy Podkop/Forkop 1.x retain their existing workflow.
            sec_mixed_toggle "$sec"
            uci_commit_safe "\${PODKOP_UCI}"
''',
"transactional Forkop2 mixed toggle")
once(
'''                _fk_extra_text="<b>Метка:</b> $(html_escape "$_fk_label")"
''',
'''                _fk_extra_text="<b>Метка:</b> $(html_escape "$_fk_label")"
                if forkop_v2; then
                    local _actual_mixed _actual_mixed_en
                    _actual_mixed=$(fk2_section_mixed "$sec" | cut -d'|' -f1)
                    _actual_mixed_en=$(sec_mixed_enabled "$sec")
                    if [ -n "$_actual_mixed" ]; then
                        _fk_extra_text="\${_fk_extra_text}
<b>Mixed UCI сервер:</b> <code>$(html_escape "$_actual_mixed")</code> (enabled=\${_actual_mixed_en})"
                    else
                        _fk_extra_text="\${_fk_extra_text}
<b>Mixed UCI сервер:</b> не создан для этой секции"
                    fi
                fi
''',
"mixed server identity in section card"
)
p.write_text(s)
print("Applied Forkop2 Mixed Proxy transactional toggle and identity display")
