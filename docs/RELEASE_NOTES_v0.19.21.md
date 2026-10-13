# Release candidate: podkop_bot v0.19.21

> Candidate branch: `claude/youthful-babbage-e81kn6` (original candidate SHA `afb1036be59c2f2c12a6cf0b0ccf14c283d589c4`). This document does not certify CI or a GitHub Release publication. User reports a successful trial on a test router. Release notes cover 0.19.21 and the important 0.19.20 changes.

## GitHub Release — Русский

### Главное: бот быстрее возвращается в Telegram

Раньше авария upstream у локального sing-box SOCKS могла задерживать переход на рабочий запасной прокси на несколько минут: каждый нерабочий маршрут проверялся длинным Telegram long poll с ожиданием до 65 секунд. Теперь перед `getUpdates` бот проверяет Telegram по тому же маршруту коротким `getMe` с лимитом 8 секунд и пропускает маршрут, через который Telegram не отвечает.

Если действующий HTTP-прокси закрыл простаивающий CONNECT, но короткая проверка Telegram через него проходит, бот один раз повторит текущий маршрут, а не начнёт поиск с первого SOCKS.

**Watchdog проверяет доступность именно Telegram.** Запрос к Google `generate_204` больше не считается достаточным признаком, что SOCKS подходит для Telegram; при проверке mixed-proxy учитывается авторизация. Это предотвращает ложный возврат с рабочего резервного прокси на канал, который не пропускает Telegram.

### Новое в v0.19.21

- **Суточный отчёт:** блок «Секции» показывает режим, mixed-proxy endpoint, задержку до Telegram и текущий outbound каждой секции.
- **Маршрутная статистика за 24 часа:** ручные и URLTest-переключения, смены канала бота, время на резервном канале, Direct/аварийных IP и без Telegram. Журнал переходов хранится 8 дней.
- **Контроль неавторизованного доступа:** исправлен счётчик попыток, в суточном отчёте видны попытки за последние 24 часа.
- **Настройки бота:** уведомления сгруппированы в отдельный подраздел, экран стал компактнее. Подсказка для собственного proxy предлагает корректный URL-пример.

### Важное из v0.19.20

- **Режимы алертов:** «Умные» (по умолчанию), «Только критичные», «Все», «Выключены». Короткие сбои и одиночные перезапуски sing-box больше не засоряют чат; оповещения отделены от логики восстановления транспорта.
- **Стабильность уведомлений:** исправлено сообщение о недоступности Telegram и исключены ложные алерты на перезапуски sing-box, вызванные самим ботом.
- **URLTest:** понятные подтверждения опасных изменений; выбор режима и кнопки отражают фактическое действие.
- **Диагностика внешнего IP:** резервные GeoIP-провайдеры при сбоях и лимитах ipapi.co.

### Совместимость и обновление

Работает на OpenWrt с `opkg` или `apk` и поддерживаемыми вариантами Podkop/Forkop/Forkop X. Установка/обновление — через `install.sh` из официального репозитория либо штатную кнопку обслуживания бота. Существующую UCI-конфигурацию следует сохранить перед обновлением. Если используется LuCI Podkop BearGuard, совместимость его vendored-копии с 0.19.21 нужно проверить отдельно: выпуск standalone не означает автоматическую синхронизацию LuCI.

**Проверка перед публикацией:** сверить исполняемый `podkop_bot.sh`, `version.txt`, installer, RU/EN changelogs; проверить `sh -n`/ash syntax, lint/static checks, обновление существующей конфигурации и восстановление связи при нерабочем tier1. На целевом SHA нужен подтверждённый CI результат. Hardware: успешная проверка пользователем на одном тестовом роутере; это не универсальный HW PASS.

---

## GitHub Release — English

### Highlight: fast Telegram-aware transport failover

A dead sing-box SOCKS upstream could previously stall the bot for up to 65 seconds per route, delaying access to a healthy fallback proxy by minutes. Each candidate transport path now gets a short Telegram `getMe` preflight (8-second cap) before the long `getUpdates` poll. A failed path is skipped quickly; meaningful Telegram HTTP responses remain handled by the main request.

If an HTTP proxy closes an idle CONNECT tunnel but the preflight still succeeds, the bot retries the current tier once rather than restarting discovery from a dead primary SOCKS.

The watchdog now measures **Telegram reachability**, not Google `generate_204` reachability, and includes mixed-proxy credentials in liveness tests.

### Additional improvements

- **Daily reports:** per-section mode, local mixed proxy, Telegram latency and active outbound; 24-hour route transitions, manual/URLTest switches and time spent on fallback, direct, emergency or disconnected routes. Transition history is retained for eight days.
- **Security telemetry:** repaired unauthorized-attempt counter and added 24-hour attempt statistics.
- **Settings:** notifications consolidated into a dedicated submenu; clearer bot-proxy input hint.
- **From v0.19.20:** smart/critical/all/off connection alerts; reduced sing-box restart noise; recovery IPC independent of notification preferences; corrected Telegram-unreachable alert; clearer URLTest confirmations; GeoIP fallback.

**Validation:** user reports a successful test-router deployment. Exact-SHA CI and broader hardware validation must be confirmed before claiming release PASS. GitHub Release/tag is not published by this document.
