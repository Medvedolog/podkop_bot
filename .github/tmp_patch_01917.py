from pathlib import Path

p = Path('podkop_bot.sh')
s = p.read_text()

# Version bump.
s = s.replace('Podkop Telegram Bot v0.19.16', 'Podkop Telegram Bot v0.19.17', 1)
s = s.replace('BOT_VERSION="0.19.16"', 'BOT_VERSION="0.19.17"', 1)

# Anonymous-admin default: explicit opt-in only.
old = 'ALLOW_ANON_ADMINS=$(uci -q get podkop_bot.settings.allow_anonymous_admins 2>/dev/null)\n[ -z "$ALLOW_ANON_ADMINS" ] && ALLOW_ANON_ADMINS="1"'
new = 'ALLOW_ANON_ADMINS=$(uci -q get podkop_bot.settings.allow_anonymous_admins 2>/dev/null)\n[ -z "$ALLOW_ANON_ADMINS" ] && ALLOW_ANON_ADMINS="0"'
assert old in s
s = s.replace(old, new, 1)

# Security state files.
anchor = 'BOT_ID=""\n\nTARGET_CHAT_ID="$ADMIN_ID"'
insert = '''BOT_ID=""\n\n# Security controls. Persistent manual blocklists live in UCI; transient abuse\n# counters stay in /tmp so hostile traffic never causes flash-write amplification.\nSECURITY_GLOBAL_FILE="${BOT_DIR}/security_global"\nSECURITY_PREFIX="${BOT_DIR}/security_actor"\nSECURITY_WINDOW_SEC=60\nSECURITY_STRIKE_LIMIT=5\nSECURITY_BLOCK_SEC=3600\nSECURITY_ALERT_WINDOW_SEC=600\nSECURITY_ALERT_LIMIT=5\nUPLOAD_SESSION_TTL=300\n\nTARGET_CHAT_ID="$ADMIN_ID"'''
assert anchor in s
s = s.replace(anchor, insert, 1)

# Security helper functions after actor authorization helpers.
anchor = '''is_allowed_actor() {\n    [ "$3" = "true" ] && return 1\n    is_whitelisted_admin "$1" && return 0\n    [ "$4" = "1" ] && is_whitelisted_sender_chat "$2" && return 0\n    return 1\n}\n\nis_private_chat()'''
helpers = '''is_allowed_actor() {\n    [ "$3" = "true" ] && return 1\n    is_whitelisted_admin "$1" && return 0\n    [ "$4" = "1" ] && is_whitelisted_sender_chat "$2" && return 0\n    return 1\n}\n\n# Manual blocklists are anti-abuse controls for actors that are not authorized.\n# Authorized admins intentionally take precedence so an accidental list entry\n# cannot lock the owner out of the router.\nis_manually_blocked_actor() {\n    local _uid="$1" _scid="$2" _v\n    if [ -n "$_uid" ] && [ "$_uid" != "null" ]; then\n        for _v in $(uci -q get podkop_bot.settings.blocked_user_ids 2>/dev/null); do\n            [ "$_uid" = "$_v" ] && return 0\n        done\n    fi\n    if [ -n "$_scid" ] && [ "$_scid" != "null" ]; then\n        for _v in $(uci -q get podkop_bot.settings.blocked_sender_chat_ids 2>/dev/null); do\n            [ "$_scid" = "$_v" ] && return 0\n        done\n    fi\n    return 1\n}\n\n_security_actor_file() {\n    local _uid="$1" _scid="$2" _kind _id _safe\n    if [ -n "$_uid" ] && [ "$_uid" != "null" ]; then\n        _kind="user"; _id="$_uid"\n    else\n        _kind="sender"; _id="$_scid"\n    fi\n    _safe=$(printf '%s' "$_id" | tr -cd '0-9-')\n    [ -n "$_safe" ] || _safe="unknown"\n    printf '%s_%s_%s' "$SECURITY_PREFIX" "$_kind" "$_safe"\n}\n\n# Sets SECURITY_EVENT to: alert | journal | blocked_new | blocked.\nsecurity_note_unauthorized() {\n    local _uid="$1" _scid="$2" _now _f _count=0 _start=0 _until=0\n    _now=$(date +%s)\n    _f=$(_security_actor_file "$_uid" "$_scid")\n    if [ -f "$_f" ]; then\n        IFS='|' read -r _count _start _until < "$_f"\n    fi\n    case "$_count" in ''|*[!0-9]*) _count=0 ;; esac\n    case "$_start" in ''|*[!0-9]*) _start=0 ;; esac\n    case "$_until" in ''|*[!0-9]*) _until=0 ;; esac\n    if [ "$_until" -gt "$_now" ]; then\n        SECURITY_EVENT="blocked"\n        return 0\n    fi\n    if [ $((_now - _start)) -gt "$SECURITY_WINDOW_SEC" ]; then\n        _count=0; _start="$_now"; _until=0\n    fi\n    [ "$_start" -eq 0 ] && _start="$_now"\n    _count=$((_count + 1))\n    if [ "$_count" -ge "$SECURITY_STRIKE_LIMIT" ]; then\n        _until=$((_now + SECURITY_BLOCK_SEC))\n        SECURITY_EVENT="blocked_new"\n    elif [ "$_count" -eq 1 ]; then\n        SECURITY_EVENT="alert"\n    else\n        SECURITY_EVENT="journal"\n    fi\n    printf '%s|%s|%s\\n' "$_count" "$_start" "$_until" > "$_f"\n}\n\n# Global alert limiter. Sets SECURITY_SUPPRESSED to the number suppressed in the\n# previous 10-minute window when a new window starts.\nsecurity_allow_alert() {\n    local _now _count=0 _start=0 _supp=0\n    _now=$(date +%s); SECURITY_SUPPRESSED=0\n    if [ -f "$SECURITY_GLOBAL_FILE" ]; then\n        IFS='|' read -r _count _start _supp < "$SECURITY_GLOBAL_FILE"\n    fi\n    case "$_count" in ''|*[!0-9]*) _count=0 ;; esac\n    case "$_start" in ''|*[!0-9]*) _start=0 ;; esac\n    case "$_supp" in ''|*[!0-9]*) _supp=0 ;; esac\n    if [ "$_start" -eq 0 ] || [ $((_now - _start)) -gt "$SECURITY_ALERT_WINDOW_SEC" ]; then\n        SECURITY_SUPPRESSED="$_supp"\n        _count=0; _start="$_now"; _supp=0\n    fi\n    if [ "$_count" -ge "$SECURITY_ALERT_LIMIT" ]; then\n        _supp=$((_supp + 1))\n        printf '%s|%s|%s\\n' "$_count" "$_start" "$_supp" > "$SECURITY_GLOBAL_FILE"\n        return 1\n    fi\n    _count=$((_count + 1))\n    printf '%s|%s|%s\\n' "$_count" "$_start" "$_supp" > "$SECURITY_GLOBAL_FILE"\n    return 0\n}\n\nis_private_chat()'''
assert anchor in s
s = s.replace(anchor, helpers, 1)

# Bind upload session to primary owner + private chat + timestamp.
old = '''        "cmd_upload_bot_script")\n            echo "wait_bot_script_file" > "$STATE_FILE"\n            send_or_edit "$mid" \\\n'''
new = '''        "cmd_upload_bot_script")\n            if [ "${user_id:-}" != "$ADMIN_ID" ] || [ "${chat_type:-}" != "private" ]; then\n                send_or_edit "$mid" "$(printf '%s Загрузка исполняемого скрипта разрешена только основному администратору в личном чате.' "$E_ERR")" ""\n                return\n            fi\n            {\n                printf 'wait_bot_script_file\\n%s\\n%s\\n%s\\n' "$user_id" "$chat_id" "$(date +%s)"\n            } > "$STATE_FILE"\n            send_or_edit "$mid" \\\n'''
assert old in s
s = s.replace(old, new, 1)

# Strict document upload gate: active, owner-bound, private and fresh session only.
old = '''            _cur_doc_state=$(head -n1 "$STATE_FILE" 2>/dev/null)\n            # Accept a bot-script upload whether or not wait_bot_script_file state\n            # is set — /tmp state can be cleared by a restart between pressing\n            # "Upload Bot Script" and sending the file. To avoid downloading every\n            # attachment an admin sends, gate on filename + size metadata BEFORE\n            # fetching. Safety of the install itself still depends on the admin\n            # gate (above) + shebang + BOT_VERSION + syntax check (below).\n            _doc_name=$(printf '%s' "$update" | jq -r '.message.document.file_name // empty' 2>/dev/null)\n            _doc_size=$(printf '%s' "$update" | jq -r '.message.document.file_size // 0' 2>/dev/null)\n            _doc_ok=0\n            case "$_doc_name" in\n                podkop_bot*.sh|podkop_bot|*podkop_bot*.sh) _doc_ok=1 ;;\n            esac\n            # If explicitly waiting for a script (user just tapped Upload), accept\n            # any name — the intent is unambiguous.\n            [ "$_cur_doc_state" = "wait_bot_script_file" ] && _doc_ok=1\n'''
new = '''            _cur_doc_state=$(head -n1 "$STATE_FILE" 2>/dev/null)\n            _upload_uid=$(sed -n '2p' "$STATE_FILE" 2>/dev/null)\n            _upload_chat=$(sed -n '3p' "$STATE_FILE" 2>/dev/null)\n            _upload_ts=$(sed -n '4p' "$STATE_FILE" 2>/dev/null)\n            _upload_now=$(date +%s)\n            case "$_upload_ts" in ''|*[!0-9]*) _upload_ts=0 ;; esac\n            if [ "$_cur_doc_state" != "wait_bot_script_file" ] || \\\n               [ "$chat_type" != "private" ] || [ "$user_id" != "$ADMIN_ID" ] || \\\n               [ "$_upload_uid" != "$user_id" ] || [ "$_upload_chat" != "$chat_id" ] || \\\n               [ $((_upload_now - _upload_ts)) -lt 0 ] || \\\n               [ $((_upload_now - _upload_ts)) -gt "$UPLOAD_SESSION_TTL" ]; then\n                [ "$_cur_doc_state" = "wait_bot_script_file" ] && rm -f "$STATE_FILE"\n                continue\n            fi\n            _doc_name=$(printf '%s' "$update" | jq -r '.message.document.file_name // empty' 2>/dev/null)\n            _doc_size=$(printf '%s' "$update" | jq -r '.message.document.file_size // 0' 2>/dev/null)\n            _doc_ok=0\n            case "$_doc_name" in\n                podkop_bot*.sh|podkop_bot) _doc_ok=1 ;;\n            esac\n'''
assert old in s
s = s.replace(old, new, 1)

# Replace unauthorised raw-payload logging/alert logic with bounded machine logs.
start = s.index('        # Authorization check\n        if ! is_allowed_actor')
end = s.index('\n        [ "$chat_type" = "channel" ] && continue', start)
old_block = s[start:end]
new_block = '''        # Authorization check. Allowlist is the security boundary; blocklists and\n        # rate limits only reduce abuse from actors that already failed it.\n        if ! is_allowed_actor "$user_id" "$sender_chat_id" "$is_bot_sender" "$ALLOW_ANON_ADMINS"; then\n            if is_manually_blocked_actor "$user_id" "$sender_chat_id"; then\n                continue\n            fi\n            security_note_unauthorized "$user_id" "$sender_chat_id"\n            _sec_actor="user"; _sec_id="$user_id"\n            if [ -z "$_sec_id" ] || [ "$_sec_id" = "null" ]; then\n                _sec_actor="sender_chat"; _sec_id="$sender_chat_id"\n            fi\n            case "$SECURITY_EVENT" in\n                blocked) continue ;;\n                blocked_new)\n                    logger -t podkop-bot "[Security] unauthorized actor=${_sec_actor} id=${_sec_id:-unknown} action=temp_block duration=${SECURITY_BLOCK_SEC}s" ;;\n                *)\n                    logger -t podkop-bot "[Security] unauthorized actor=${_sec_actor} id=${_sec_id:-unknown} event=update" ;;\n            esac\n            if [ "$is_bot_sender" != "true" ] && [ "$SECURITY_EVENT" != "journal" ] && security_allow_alert; then\n                safe_u_name=$(html_escape "${u_name:-не указано}")\n                safe_alert_text=$(printf '%.120s' "$text" | tr '\\r\\n\\t' '   ')\n                safe_alert_text=$(html_escape "$safe_alert_text")\n                _sec_note=""\n                [ "$SECURITY_EVENT" = "blocked_new" ] && _sec_note="\\n<b>Действие:</b> временная блокировка на 1 час"\n                [ "${SECURITY_SUPPRESSED:-0}" -gt 0 ] 2>/dev/null && _sec_note="${_sec_note}\\n<b>Подавлено ранее:</b> ${SECURITY_SUPPRESSED}"\n                alert_txt=$(cat <<EOF\n${E_WARN} <b>Попытка несанкционированного доступа</b>\n<b>Пользователь:</b> @${safe_u_name} (ID: <code>${_sec_id:-unknown}</code>)\n<b>Сообщение:</b> <code>${safe_alert_text}</code>${_sec_note}\nEOF\n)\n                alert_payload=$(jq -n -c --arg cid "$ADMIN_ID" --arg txt "$alert_txt" \\\n                    '{chat_id:$cid,text:$txt,parse_mode:"HTML"}')\n                api_request "sendMessage" "$alert_payload" >/dev/null\n            fi\n            continue\n        fi\n'''
s = s[:start] + new_block + s[end:]

# Changelog/version surfaces.
vp = Path('version.txt')
if vp.exists():
    vp.write_text('0.19.17\n')
cp = Path('CHANGELOG.md')
if cp.exists():
    cs = cp.read_text()
    marker = '# Changelog\n\n'
    if marker in cs:
        entry = '''# Changelog\n\n## v0.19.17\n\n- **SECURITY:** anonymous-admin sender_chat access is now opt-in (default off).\n- **SECURITY:** executable bot uploads require a fresh 5-minute session started by the primary admin in a private chat; extra admins and sender_chat identities cannot upload code.\n- **SECURITY:** unauthorized actors get per-actor temporary blocking after 5 attempts in 60 seconds plus a global alert limiter; manual UCI blocklists are supported via `blocked_user_ids` and `blocked_sender_chat_ids`.\n- **SECURITY:** attacker-controlled Telegram text is no longer written verbatim to syslog.\n\n'''
        cs = cs.replace(marker, entry, 1)
    cp.write_text(cs)

p.write_text(s)

# Invariants for the staged patch.
s = p.read_text()
assert 'BOT_VERSION="0.19.17"' in s
assert '[ -z "$ALLOW_ANON_ADMINS" ] && ALLOW_ANON_ADMINS="0"' in s
assert 'UPLOAD_SESSION_TTL=300' in s
assert 'blocked_user_ids' in s and 'blocked_sender_chat_ids' in s
assert 'action=temp_block' in s
assert 'text=${text}' not in s
assert 'wait_bot_script_file\\n%s\\n%s\\n%s\\n' in s
