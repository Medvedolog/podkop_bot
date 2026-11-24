#!/usr/bin/env python3
"""Podkop Experimental v0.8.13 read-side compatibility and bot 0.20.1 bump."""
from pathlib import Path
p=Path("podkop_bot.sh")
s=p.read_text()
def once(old,new,why):
    global s
    n=s.count(old)
    if n != 1: raise SystemExit(f"{why}: expected one exact anchor, got {n}")
    s=s.replace(old,new,1)
once('BOT_VERSION="0.20.0"','BOT_VERSION="0.20.1"',"BOT_VERSION")
once(
'⭐ основные строки — из них URLTest выбирает быстрый сервер. 🛟 резервные — пробуются по порядку, когда основные не отвечают.',
'⭐ основные строки — участвуют в режиме выбора сервера. 🛟 резервные — используются по порядку при недоступности основных.',
"experimental section UX"
)
once(
'''            send_or_edit "$mid" "$(printf '%s <b>Серверы секции</b>''',
'''            # Podkop Experimental 0.8.13 adds server_choice=loss/balance;
            # do not claim "fastest" when the native engine selects otherwise.
            # Cure sections are per-server engine settings and are read-only here.
            local _xp_choice _xp_choice_human _xp_cure_count
            _xp_choice=$(uci -q get "\${PODKOP_UCI}.\${sec}.server_choice" 2>/dev/null)
            case "$_xp_choice" in
                ''|fastest) _xp_choice=fastest; _xp_choice_human="минимальная задержка" ;;
                loss) _xp_choice_human="с учётом потерь" ;;
                balance) _xp_choice_human="балансировка" ;;
                *) _xp_choice_human="неизвестный режим (только просмотр)" ;;
            esac
            _xp_cure_count=$(uci -q show "\${PODKOP_UCI}" 2>/dev/null | grep -Ec "^\${PODKOP_UCI}\\.[^.]+=cure$" || true)
            case "$_xp_cure_count" in ''|*[!0-9]*) _xp_cure_count=0 ;; esac
            _body="\${_body}
<b>Режим:</b> $(html_escape "$_xp_choice_human") (<code>$(html_escape "$_xp_choice")</code>)
<b>Индивидуальные обходы (cure):</b> \${_xp_cure_count} · управление в LuCI"
            send_or_edit "$mid" "$(printf '%s <b>Серверы секции</b>''',
"experimental 0.8.13 mode display"
)
p.write_text(s)
print("Applied v0.20.1 and Experimental 0.8.13 read-side display")
