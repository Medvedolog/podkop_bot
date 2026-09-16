from pathlib import Path

p = Path('podkop_bot.sh')
s = p.read_text()

old = '''# Shared tsnet backend for Telegram. Native Forkop, Forkop X and classic Podkop
# converge on the same provider abstraction used by LuCI.
_ts_backend_call() {
    local _method="$1" _payload="${2:-{}}"
    [ -x /usr/libexec/rpcd/podkop_bot_tailscale ] || return 1
    printf '%s' "$_payload" | /usr/libexec/rpcd/podkop_bot_tailscale call "$_method" 2>/dev/null
}
_ts_backend_status() { _ts_backend_call status '{}'; }
_ts_backend_provider() { _ts_backend_status | jq -r '.provider // "none"' 2>/dev/null; }
'''
new = '''# Shared tsnet backend for Telegram. The standalone bot is deliberately
# read-only for Tailscale unless a compatible controller backend is installed.
TS_BACKEND_API_REQUIRED=1
TS_BACKEND_PATH=/usr/libexec/rpcd/podkop_bot_tailscale

_ts_backend_api_version() {
    [ -x "$TS_BACKEND_PATH" ] || return 1
    "$TS_BACKEND_PATH" list 2>/dev/null | jq -r '.api_version // 0' 2>/dev/null
}
_ts_backend_control_state() {
    [ -x "$TS_BACKEND_PATH" ] || { printf '%s' missing; return 1; }
    local _v
    _v=$(_ts_backend_api_version 2>/dev/null)
    [ "$_v" = "$TS_BACKEND_API_REQUIRED" ] || { printf '%s' incompatible; return 1; }
    printf '%s' ready
}
_ts_backend_control_available() { [ "$(_ts_backend_control_state 2>/dev/null)" = ready ]; }
_ts_backend_call() {
    local _method="$1" _payload="${2:-{}}"
    _ts_backend_control_available || return 2
    printf '%s' "$_payload" | "$TS_BACKEND_PATH" call "$_method" 2>/dev/null
}
_ts_backend_status() { _ts_backend_call status '{}'; }
_ts_backend_provider() { _ts_backend_status | jq -r '.provider // "none"' 2>/dev/null; }
'''
if old not in s:
    raise SystemExit('backend helper anchor not found')
s = s.replace(old, new, 1)

s = s.replace('if singbox_supports_tailscale; then', 'if singbox_supports_tailscale && _ts_backend_control_available; then')

old = '''                    if [ "$_ts_legacy" = 1 ]; then
                        _ts_toggle_rows="${_ts_toggle_rows}[{\\"text\\":\\"🗑 Удалить старую Tailscale-секцию\\",\\"callback_data\\":\\"ts_ld_${_s}\\"}],"
                    else
'''
new = '''                    if ! _ts_backend_control_available; then
                        : # observer mode: render status only, never mutation buttons
                    elif [ "$_ts_legacy" = 1 ]; then
                        _ts_toggle_rows="${_ts_toggle_rows}[{\\"text\\":\\"🗑 Удалить старую Tailscale-секцию\\",\\"callback_data\\":\\"ts_ld_${_s}\\"}],"
                    else
'''
if old not in s:
    raise SystemExit('tailscale toggle anchor not found')
s = s.replace(old, new, 1)

old = '''        ts_add|ts_add_confirm|ts_ld_*|ts_ldc_*|ts_e_*|ts_ec_*|ts_x_*|ts_r_*)
            _handle_forkop_ext "$cmd" "$mid" "" "" "$cb_id" ;;
'''
new = '''        ts_add|ts_add_confirm|ts_ld_*|ts_ldc_*|ts_e_*|ts_ec_*|ts_x_*|ts_r_*)
            if _ts_backend_control_available; then
                _handle_forkop_ext "$cmd" "$mid" "" "" "$cb_id"
            else
                case "$(_ts_backend_control_state 2>/dev/null)" in
                    incompatible) CB_ANSWER_TEXT="Tailscale: backend API несовместим — только наблюдение" ;;
                    *)            CB_ANSWER_TEXT="Tailscale: backend не установлен — только наблюдение" ;;
                esac
                _handle_bot "cmd_server_instances" "$mid" "" ""
            fi
            ;;
'''
if old not in s:
    raise SystemExit('router ts callback anchor not found')
s = s.replace(old, new, 1)

old = '''            local _text_nl
            _text_nl=$(printf '%s' "$_text" | awk '{gsub(/\\\\n/,"\\n")}1')
'''
new = '''            local _text_nl
            _text_nl=$(printf '%s' "$_text" | awk '{gsub(/\\\\n/,"\\n")}1')
            if ! _ts_backend_control_available; then
                local _ts_ctl_state _ts_ctl_note
                _ts_ctl_state=$(_ts_backend_control_state 2>/dev/null)
                if [ "$_ts_ctl_state" = incompatible ]; then
                    _ts_ctl_note="Установленный backend имеет несовместимую версию API."
                else
                    _ts_ctl_note="Backend управления не установлен."
                fi
                _text_nl="${_text_nl}\\n\\nℹ️ <b>Tailscale: режим наблюдения.</b> ${_ts_ctl_note}\\nСоздание, изменение и удаление появятся автоматически с совместимым backend API v${TS_BACKEND_API_REQUIRED} (luci-app-podkop-bot r60+)."
            fi
'''
if old not in s:
    raise SystemExit('services text anchor not found')
s = s.replace(old, new, 1)

s = s.replace('Не удалось сохранить Tailscale в UCI — изменение отменено.',
              'Не удалось сохранить Tailscale через backend — изменение отменено.')

p.write_text(s)
