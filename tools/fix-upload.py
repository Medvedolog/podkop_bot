from pathlib import Path

p = Path('podkop_bot.sh')
s = p.read_text()

old = '''            _doc_name=$(printf '%s' "$update" | jq -r '.message.document.file_name // empty' 2>/dev/null)
            _doc_size=$(printf '%s' "$update" | jq -r '.message.document.file_size // 0' 2>/dev/null)
            _doc_ok=0
            case "$_doc_name" in
                podkop_bot*.sh|podkop_bot) _doc_ok=1 ;;
            esac
            case "$_doc_size" in ''|*[!0-9]*) _doc_size=0 ;; esac
            # Valid-looking bot script but too large: tell the user explicitly
            # instead of silently ignoring it (which would leave the wait state
            # set and no feedback about why nothing happened).
            if [ "$_doc_ok" = "1" ] && [ "$_doc_size" -gt 2097152 ]; then
'''
new = '''            _doc_name=$(printf '%s' "$update" | jq -r '.message.document.file_name // empty' 2>/dev/null)
            _doc_size=$(printf '%s' "$update" | jq -r '.message.document.file_size // 0' 2>/dev/null)
            case "$_doc_size" in ''|*[!0-9]*) _doc_size=0 ;; esac
            # The explicit upload session is already bound to admin + private chat
            # + chat/user IDs + TTL. Filename is cosmetic and must not be another
            # security gate: Telegram/users routinely rename the same valid script.
            # Accept any document here and decide only from size + file contents.
            if [ "$_doc_size" -gt 2097152 ]; then
'''
if old not in s:
    raise SystemExit('filename gate anchor missing')
s = s.replace(old, new, 1)

old = '''            if [ "$_doc_ok" = "1" ] && [ "$_doc_size" -le 2097152 ]; then
'''
new = '''            if [ "$_doc_size" -le 2097152 ]; then
'''
if old not in s:
    raise SystemExit('accept condition anchor missing')
s = s.replace(old, new, 1)

old = 'Отправьте файл <code>podkop_bot.sh</code> как документ.'
new = 'Отправьте скрипт бота как документ. Имя файла может быть любым.'
if old not in s:
    raise SystemExit('prompt anchor missing')
s = s.replace(old, new, 1)

old = '''                if ! head -1 "$_bot_tmp" | grep -q '^#!' || ! grep -q '^BOT_VERSION=' "$_bot_tmp"; then
'''
new = '''                if ! head -1 "$_bot_tmp" | grep -q '^#!' || ! grep -q '^[[:space:]]*BOT_VERSION=' "$_bot_tmp"; then
'''
if old not in s:
    raise SystemExit('content gate anchor missing')
s = s.replace(old, new, 1)

p.write_text(s)
