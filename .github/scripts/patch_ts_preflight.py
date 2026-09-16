from pathlib import Path
import re

path = Path('podkop_bot.sh')
s = path.read_text()

marker = '# ── Tailscale server management (Forkop)'
helper = '''# Detect a classic standalone Tailscale installation separately from sing-box
# tsnet. A running tailscaled is not an automatic error, but creating/enabling a
# second Tailscale node must require an explicit operator confirmation.
_ts_standalone_present() {
    [ -x /etc/init.d/tailscale ] || [ -x /etc/init.d/tailscaled ] || \\
        command -v tailscaled >/dev/null 2>&1 || command -v tailscale >/dev/null 2>&1
}

_ts_standalone_running() {
    local _svc _c _cl
    for _svc in /etc/init.d/tailscale /etc/init.d/tailscaled; do
        [ -x "$_svc" ] || continue
        "$_svc" running >/dev/null 2>&1 && return 0
        "$_svc" status >/dev/null 2>&1 && return 0
    done
    for _c in /proc/[0-9]*/cmdline; do
        [ -r "$_c" ] || continue
        _cl=$(tr '\\0' ' ' < "$_c" 2>/dev/null) || continue
        case "$_cl" in *tailscaled*) return 0 ;; esac
    done
    return 1
}
'''
if '_ts_standalone_running()' not in s:
    if marker not in s:
        raise SystemExit('tailscale marker not found')
    s = s.replace(marker, helper + '\n' + marker, 1)

if 'ts_add_confirm' not in s:
    rx = re.compile(r'(?m)^([ \t]*)(?:"ts_add"\)|ts_add\))[ \t]*$')
    m = rx.search(s)
    if not m:
        raise SystemExit('ts_add case not found')
    ind = m.group(1)
    body = ind + '    '
    guard = (
        ind + '"ts_add"|"ts_add_confirm")\n' +
        body + 'if [ "$cmd" = "ts_add" ] && _ts_standalone_running; then\n' +
        body + '    send_or_edit "$mid" \\\n' +
        body + '        "$(printf \'%s <b>Уже работает отдельный Tailscale (tailscaled).</b>\\n\\nForkop запустит второй узел через встроенный tsnet sing-box. Это допустимо, но может дать два узла, пересекающиеся маршруты или неожиданный выбор exit node.\\n\\nПродолжить всё равно?\' "$E_WARN")" \\\n' +
        body + '        "{\\"inline_keyboard\\":[[{\\"text\\":\\"⚠️ Продолжить всё равно\\",\\"callback_data\\":\\"ts_add_confirm\\"}],[{\\"text\\":\\"${E_BACK} Отмена\\",\\"callback_data\\":\\"cmd_server_instances\\"}]]}"\n' +
        body + '    return\n' +
        body + 'fi'
    )
    s = s[:m.start()] + guard + s[m.end():]

if 'ts_ec_' not in s:
    rx = re.compile(r'(?m)^([ \t]*)(?:"ts_e_"\*\)|ts_e_\*\))[ \t]*$')
    m = rx.search(s)
    if not m:
        raise SystemExit('ts_e_* case not found')
    ind = m.group(1)
    body = ind + '    '
    guard = (
        ind + '"ts_e_"*|"ts_ec_"*)\n' +
        body + 'local _ts_confirmed=0 _ts_target _ts_payload\n' +
        body + 'case "$cmd" in\n' +
        body + '    ts_ec_*) _ts_confirmed=1; cmd="ts_e_${cmd#ts_ec_}" ;;\n' +
        body + 'esac\n' +
        body + '_ts_target="${cmd##*_}"\n' +
        body + 'if [ "$_ts_target" = "1" ] && [ "$_ts_confirmed" != "1" ] && _ts_standalone_running; then\n' +
        body + '    _ts_payload="${cmd#ts_e_}"\n' +
        body + '    send_or_edit "$mid" \\\n' +
        body + '        "$(printf \'%s <b>Standalone Tailscale уже запущен.</b>\\n\\nВключить одновременно встроенный tsnet sing-box? Оба узла останутся самостоятельными.\' "$E_WARN")" \\\n' +
        body + '        "{\\"inline_keyboard\\":[[{\\"text\\":\\"⚠️ Включить всё равно\\",\\"callback_data\\":\\"ts_ec_${_ts_payload}\\"}],[{\\"text\\":\\"${E_BACK} Отмена\\",\\"callback_data\\":\\"cmd_server_instances\\"}]]}"\n' +
        body + '    return\n' +
        body + 'fi'
    )
    s = s[:m.start()] + guard + s[m.end():]

path.write_text(s)
