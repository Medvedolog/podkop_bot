#!/usr/bin/env python3
"""Forkop2 native Tailscale capability explanation; NO UCI writes."""
from pathlib import Path
p=Path("podkop_bot.sh")
s=p.read_text()
def once(old,new,name):
    global s
    n=s.count(old)
    if n!=1: raise SystemExit(f"{name}: expected one matching source block, found {n}")
    s=s.replace(old,new,1)

once(
'''                    _ts_empty_add='[{"text":"➕ Tailscale через sing-box","callback_data":"ts_add"}],'
                fi''',
'''                    _ts_empty_add='[{"text":"➕ Tailscale через sing-box","callback_data":"ts_add"}],'
                elif _forkop_v2; then
                    _ts_empty_add='[{"text":"ℹ️ Tailscale: проверить поддержку ядра","callback_data":"ts_cap_info"}],'
                fi''',
"empty services diagnostic button")
once(
'''                [ -n "$_ts_existing" ] || _ts_row="[{\"text\":\"➕ Tailscale через sing-box\",\"callback_data\":\"ts_add\"}],"
            fi''',
'''                [ -n "$_ts_existing" ] || _ts_row="[{\"text\":\"➕ Tailscale через sing-box\",\"callback_data\":\"ts_add\"}],"
            elif _forkop_v2; then
                _ts_row='[{"text":"ℹ️ Tailscale: проверить поддержку ядра","callback_data":"ts_cap_info"}],'
            fi''',
"populated services diagnostic button")
once('''        "ts_add")
''',
'''        "ts_cap_info")
            # Read only two booleans from ubus. Never print the full state or
            # call a second sing-box process on constrained OpenWrt devices.
            local _ts_state _ts_known=unknown _ts_avail=unknown _ts_guidance
            if ! _forkop_v2; then
                CB_ANSWER_TEXT="Диагностика предназначена для Forkop 2"
                return
            fi
            _ts_state=$(ubus call forkop state '{}' 2>/dev/null) || _ts_state=''
            if [ -n "$_ts_state" ]; then
                _ts_known=$(printf '%s' "$_ts_state" | jq -r '.capabilities.core.known // false' 2>/dev/null)
                _ts_avail=$(printf '%s' "$_ts_state" | jq -r '.capabilities.core.features.tailscale.available // false' 2>/dev/null)
            fi
            if [ "$_ts_known" = true ] && [ "$_ts_avail" = true ]; then
                _ts_guidance="Ядро подтверждает Tailscale. Если мастер недоступен, проверьте совместимость backend BearGuard и версию бота."
            elif [ "$_ts_known" != true ]; then
                _ts_guidance="Forkop не подтвердил возможности ядра. Проверьте, запущен ли штатный state-service и доступен ли <code>ubus call forkop state '{}'</code>."
            else
                _ts_guidance="Установленная сборка sing-box не предоставляет native Tailscale. Нужна совместимая сборка full с <code>with_tailscale</code> и <code>with_gvisor</code>."
            fi
            send_or_edit "$mid" "$(printf '%s <b>Forkop 2: Tailscale через sing-box</b>\n\n<b>Данные ядра известны:</b> <code>%s</code>\n<b>Tailscale доступен:</b> <code>%s</code>\n\n%s\n\n<i>Это только чтение состояния. Настройки Forkop не изменены.</i>' "$E_SET" "$_ts_known" "$_ts_avail" "$_ts_guidance")" \
                "{\"inline_keyboard\":[[{\"text\":\"← К службам\",\"callback_data\":\"cmd_server_instances\"}]]}"
            ;;
        "ts_add")
''',
"native Tailscale capability callback"
)
p.write_text(s)
print("Forkop2 read-only Tailscale capability explanation enabled")
