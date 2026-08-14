# 📖 Структура меню podkop_bot — справочник карточек

> Документ описывает экраны (карточки) Telegram-бота для управления [podkop](https://podkop.net).
> Для каждой карточки указан заголовок, строки данных и кнопки с описанием действия.
>
> 🇷🇺 **Интерфейс бота русский начиная с v0.18.x.** Все подписи ниже приведены так, как они
> выглядят на экране. Английскими остаются только технические термины: названия протоколов,
> поля UCI, `URLTest`, `SOCKS`, `DNS`, `YACD`, `sing-box`, `Zapret`, `ByeDPI`.

---

## Навигационное дерево

Кнопки главного экрана расположены в два столбца — так они и показаны здесь.

```
🖥️ Управление Podkop  (/menu · main_menu)
├── 📊 Статус  cmd_status              │ 🌐 Прокси  (цель зависит от режима секции)
│   └── 🧭 Подробнее  cmd_runtime      │   ├── proxy_menu ....... Selector / URLTest / подписка
│       ├── 🧪 Диагностика             │   │   └── карточка прокси  px_view_N
│       ├── 📄 Файлы и журнал          │   ├── url_links_menu .... режим одной ссылки
│       └── 🔌 Закрыть соединения      │   ├── outbound_info ..... режим JSON-прокси
│           (только plus / forkop)     │   └── text_links_menu ... NetShift, текстовый режим
│
├── ⚙ Настройки  main_settings_menu   │ 🔄 Перезапустить  ask_reload_podkop
│   ├── ⚙ Настройки секции  section_settings
│   │   ├── Подключение · 🎯 Режим · Mixed-прокси · ✏ Порт
│   │   ├── 🎯 URLTest · 🔗 DNS-резолвер
│   │   ├── 🎯 Условия · 🔗 Через секцию      (только forkop)
│   │   ├── 🔬 Фильтры URLTest                (только plus, режим urltest)
│   │   └── включение секции и автозапуска
│   │       └── zapret_section_menu / byedpi_section_menu  (plus / forkop)
│   ├── 🌐 Общие  global_settings
│   │   └── интерфейс · интервал · QUIC · NTP в обход · DNS · YACD · контроль WAN
│   ├── 📎 Секции  sections_menu
│   └── 📄 Списки и маршруты  community_lists
│       └── готовые списки · домены · подсети · ➡ Через туннель · ↩ В обход ·
│           ✏ Мои домены · ✏ Мои подсети
│
├── 🤖 Настройки бота  bot_settings    │ 🛑 Остановить · 🟢 Запустить
│   ├── Подключение (Авто · SOCKS5 · Напрямую) · Интервал
│   ├── 🔗 Резервные SOCKS  fallback_socks_menu · 🧪 Проверить SOCKS
│   ├── ➕ Прокси бота · ➕ Привязать интерфейс
│   ├── Сообщать о запуске · о сбоях · Уведомлять всех · Контроль памяти
│   ├── Режим тишины · Ежедневный отчёт · Еженедельный отчёт
│   └── 👤 Администраторы  admins_menu
│
├── 🖧 Службы  cmd_server_instances                    (только plus / forkop)
│
└── 🔧 Обслуживание  cmd_maintenance
    ├── 🐶 Обновление Podkop · 🆕 Обновление бота
    ├── 📊 Отчёт за сутки · 📅 Отчёт за неделю
    ├── 📤 Загрузить скрипт
    ├── 🔄 Перезапустить бота
    └── 💀 Перезагрузить роутер

🧪 Диагностика  cmd_diagnostics        ← 📊 Статус → 🧭 Подробнее → 🧪 Диагностика
├── 🩺 Состояние туннеля  cmd_tunnel_health
├── 🔬 Проверить прокси · 🪺 Проверить задержки
├── 🌐 Проверка Podkop · 🧠 Проверка бота
└── 📋 Отчёт для поддержки

Постоянная reply-клавиатура (всегда внизу экрана):  [🏠 Меню] [📊 Статус]
```

---

## 🏠 Главное меню `/menu`

```
🖥️ Управление Podkop
Устройство: AX6000
Podkop: v0.7.14-r1 (Forkop) | Бот: v0.19.2
[Секция: main]             ← только при >1 секции
Активный прокси: LV-hysteria2 (main-1-out)
Подключение бота: Podkop (SOCKS5:192.168.2.1:2080)
```

| Кнопка | Действие |
|--------|----------|
| 📊 Статус | Открыть карточку системного статуса |
| 🌐 Прокси | Список прокси текущей секции. Подпись всегда одна, цель зависит от режима: `proxy_menu`, `url_links_menu` или `outbound_info` |
| ⚙ Настройки | Меню настроек podkop |
| 🔄 Перезапустить | Подтверждение → перезапуск podkop/sing-box |
| 🤖 Настройки бота | Подключение бота, уведомления, отчёты, администраторы |
| 🛑 Остановить / 🟢 Запустить | Остановить или запустить podkop (подпись меняется по факту) |
| 🖧 Службы | Живой статус серверных инстансов. Кнопка есть только на plus и forkop |
| 🔧 Обслуживание | Обновления, отчёты вручную, перезапуск бота, перезагрузка роутера |

**Строки карточки:**

| Строка | Что означает |
|--------|--------------|
| `Устройство` | Имя роутера (`/proc/sys/kernel/hostname`) |
| `Podkop` | Версия установленного пакета и в скобках — вариант (Podkop, NetShift, Podkop Plus, Forkop) |
| `Бот` | Версия запущенного бота |
| `Секция` | Активная UCI-секция (показывается только если секций больше одной) |
| `Активный прокси` | Читаемое имя активного прокси из Clash API (`#fragment` ссылки) плюс тег sing-box |
| `Подключение бота` | Каким путём бот сейчас ходит в Telegram (tier1 / tier2 / напрямую / аварийные IP) |

---

> ## ⚠️ Всё, что ниже, устарело и переписывается
>
> Навигационное дерево и карточка главного меню выше сверены с кодом v0.19.2.
> **Карточки ниже — нет.** Они описывают версию **v0.14.1** и не обновлялись пять минорных версий, поэтому расходятся с реальностью сразу в трёх местах:
>
> * **Язык.** Макеты показывают английский интерфейс (`System & Podkop Status`, `Autostart: ENABLED`, `Active Proxy`), которого нет с v0.18.x — бот полностью русский.
> * **Callback'и.** Часть идентификаторов переименована: `cmd_info` → `cmd_maintenance`, `advanced_settings` → `section_settings` и `global_settings`.
> * **Пропущенные разделы.** Здесь вовсе нет 🖧 Служб, отчёта за неделю, режима тишины, загрузки скрипта, условий и detour для Forkop, меню Zapret/ByeDPI.
>
> Пока раздел не переписан, ориентируйтесь на навигационное дерево выше и на сам бот. Значения в макетах (версии, IP, память, задержки) — иллюстративные и всегда были такими.

---

## 📊 Статус системы `cmd_status`

```
📊 System & Podkop Status
────────────────────
🖥 AX6000| 5d 3h 12m
🐧 OS: OpenWrt 24.10.5
🌐 WAN: 192.168.1.3
🌐 Public IP: 95.165.123.123    ← только если WAN ≠ Public IP (NAT)
🔗 LAN: 192.168.2.1
🌐 Tailscale (tailscale0): 100.x.x.x   ← если есть VPN-интерфейс
🧠 Load: 0.18, 0.10, 0.08
💾 Free RAM: 245 MB
────────────────────
🐶 Podkop: 🟢 RUNNING / ✅ done
🟢 Autostart: ✅ ENABLED / ❌ DISABLED
⚙️ Mode: URLTest (auto-fastest)
📦 Sing-box: 🟢 RUNNING | RAM: 28 MB
────────────────────
🌐 Active Proxy: LV-hysteria2 (main-1-out)
📨 Telegram: direct ✅ | tunnel SOCKS5 ✅ | ✅ tier2
🔗 DNS: udp | YACD: 🟢 ON
🛡 Bot Route: Podkop (SOCKS5:192.168.2.1:2080) (212ms)
```

| Строка | Что означает |
|--------|--------------|
| `Host \| uptime` | Имя роутера и время работы с последнего старта |
| `OS` | Версия OpenWrt |
| `WAN` | IP-адрес WAN-интерфейса (локальный, из маршрутизации) |
| `Public IP` | Внешний IP (из ipinfo.io/ifconfig.me, кэш 5 мин). Показывается только если отличается от WAN — значит роутер за NAT |
| `LAN` | IP LAN-интерфейса |
| VPN-строки | Автодетект: Tailscale, ZeroTier, AmneziaWG, WireGuard, tun-интерфейсы |
| `Load` | Средняя нагрузка CPU (1m, 5m, 15m) из `/proc/loadavg` |
| `Free RAM` | Свободная память (`MemAvailable`) в МБ |
| `Podkop` | 🐶 done — one-shot сервис отработал; 🟢 RUNNING — процесс podkop запущен |
| `Autostart` | Включён ли автозапуск podkop при загрузке (`/etc/init.d/podkop enabled`) |
| `Mode` | Режим прокси активной секции: Selector / URLTest / URL Connection / Outbound Config |
| `Sing-box` | Запущен ли процесс sing-box + потребление RAM |
| `Active Proxy` | Активный прокси из Clash API |
| `Telegram: direct` | ✅/❌ — прямой TCP до DC Telegram (3 адреса, без прокси) |
| `tunnel SOCKS5` | ✅/🟡/❌ — доступность Telegram через SOCKS5-туннель podkop |
| `tier2` | ✅/❌ — первый fallback SOCKS, если настроен |
| `DNS` | Тип DNS-резолвера из настроек podkop (udp/dot/doh) |
| `YACD` | Включён ли веб-дашборд Clash (YACD) |
| `Bot Route` | Транспортный путь бота + задержка до Telegram API |

| Кнопка | Действие |
|--------|----------|
| 🔍 Runtime Info | Детальная информация о подключениях и прокси |
| 🔄 Refresh | Обновить карточку статуса |
| 🏠 Menu | Вернуться в главное меню |

---

## 🔍 Runtime Info `cmd_runtime`

```
🔍 Runtime Info
────────────────────
🔌 Connections: 47
⬇ Downloaded: 1.23 GB
⬆ Uploaded: 0.45 GB
────────────────────
🌐 Active proxy: LV-hysteria2 (main-1-out)
⚙️ Type: Hysteria2 | Delay: 188ms
Selector: main-out
────────────────────
🛡 Bot route: 🟢 Podkop (SOCKS5:192.168.2.1:2080)
```

| Строка | Что означает |
|--------|--------------|
| `Connections` | Текущее число активных соединений через sing-box (Clash API `/connections`) |
| `Downloaded` | Суммарный трафик принятый через sing-box с момента последнего старта |
| `Uploaded` | Суммарный трафик отправленный |
| `Active proxy` | Активный прокси (имя + тег) |
| `Type` | Протокол активного прокси (Hysteria2, VLESS, SS...) |
| `Delay` | Последняя задержка из истории Clash API |
| `Selector` | Тег selector-группы в sing-box config |
| `Bot route` | Маршрут бота к Telegram: 🟢 если SOCKS up, 🟡 если SOCKS down |

| Кнопка | Действие |
|--------|----------|
| 🩺 Tunnel Health | Детальная диагностика туннеля |
| 🧪 Diagnostics | Меню диагностических инструментов |
| 📁 Configs & Logs | Файлы конфигурации и логи |
| 🔄 Refresh | Обновить |
| ← Back | Назад к Status |
| 🏠 Menu | Главное меню |

---

## 🩺 Tunnel Health `cmd_tunnel_health`

```
🩺 Tunnel Health [main]
────────────────────
📦 Sing-box: ✅ RUNNING
💾 PID: 2460 | RAM: 28 MB
⚙️ Mode: urltest
🔗 WAN iface: auto
🌐 Active proxy: LV-hysteria2 (main-1-out)
────────────────────
❌ TG direct: fail (no proxy, 2/3 DC)
✅ TG tunnel SOCKS5: ok / SOCKS up
✅ TG tier2 SOCKS: ok
🛡 Bot transport: Podkop (SOCKS5:192.168.2.1:2080)
🔗 Poll route: tier1 | Fast: tier1
────────────────────
⏱ Transport Latency (probed 5m ago)
🟢 tier1 (Podkop): 116ms
🟢 tier2_1 (socks5h://...): 142ms
────────────────────
📡 Active outbounds by section:
🟢 [main] LV-hysteria2 188ms | TG: ✅
🔴 [antiz] warp-out N/A | TG: ❌
────────────────────
📄 nftables rules (podkop): 6
🔄 Last reload: 4h 39m ago
────────────────────
🟢 Community Lists:
cloudflare, google_ai, meta, russia_inside, telegram, twitter
```

| Строка | Что означает |
|--------|--------------|
| `Sing-box` | Состояние процесса sing-box |
| `PID \| RAM` | PID процесса и потребление памяти |
| `Mode` | Режим прокси в UCI активной секции |
| `WAN iface` | Исходящий интерфейс (auto или конкретный) |
| `Active proxy` | Текущий активный прокси |
| `TG direct` | Прямая TCP-связь с DC Telegram (без прокси). `fail` в России — норма |
| `TG tunnel SOCKS5` | Telegram через SOCKS5-туннель podkop + состояние порта |
| `TG tier2 SOCKS` | Telegram через первый fallback SOCKS. Показывается только если настроен |
| `Bot transport` | Транспортный путь бота к Telegram |
| `Poll route / Fast` | Текущий tier для long-poll и быстрых запросов бота |
| `Transport Latency` | RTT до каждого SOCKS-эндпоинта (проверяется раз в цикл watchdog) |
| `Active outbounds by section` | Для каждой секции podkop: активный прокси, задержка, доступность Telegram через него |
| `nftables rules` | Количество правил nftables podkop (ненулевое = маршрутизация активна) |
| `Last reload` | Сколько времени назад был последний перезапуск sing-box |
| `Community Lists` | Активные community-листы (списки доменов/IP для маршрутизации) |

| Кнопка | Действие |
|--------|----------|
| 🔄 Refresh | Обновить карточку |
| ← Back | Назад к Runtime Info |
| 🏠 Menu | Главное меню |

---

## 🌐 Outbounds / Selector `proxy_menu`

```
🎯 URLTest Outbounds [main]   /  🌐 Outbound Selector [main]
Active: LV-hysteria2 (main-1-out) | URLTest: auto-selecting
                               или | Pinned manually

[0] 🔴 RU Hosting 94d | VLESS | N/A
[1] 🟢 NL Amnezia  | VLESS | 122ms
[2] ▶ LV-hysteria2 | Hysteria2 | 169ms  ← ▶ = активный
[3] 🔴 EE Hostslim | VLESS | N/A
```

| Элемент строки | Что означает |
|----------------|--------------|
| `[N]` | Порядковый номер прокси в списке |
| 🟢 / 🔴 / 🟡 | Зелёный < 300ms / Жёлтый 300–400ms / Красный > 400ms или N/A |
| `▶` | Текущий активный прокси |
| Имя прокси | Взято из `#fragment` URI-ссылки (человекочитаемое) |
| `Тип` | Протокол: VLESS, Hysteria2, SS и др. |
| `Nms / N/A` | Последняя задержка из Clash API. N/A — не было проверки |

| Кнопка | Действие |
|--------|----------|
| Нажать на строку прокси | Открыть карточку прокси (подробности + управление) |
| ⏱ Test All | Запустить проверку задержек по всем прокси через Clash API |
| ➕ Add | Добавить новую ссылку (vless://, hy2://, ss://...) |
| 🔄 Refresh | Обновить задержки из Clash API |
| 🔍 Auto / 📌 Switch to URLTest auto | В URLTest режиме: сбросить ручной выбор / переключить в авторежим |
| ← Back | Назад |
| 🏠 Menu | Главное меню |

---

## 📋 Карточка прокси `px_view_N`

```
🌐 Proxy Card [main]
────────────────────
🇱🇻 LV-hysteria2  57d
Type: Hysteria2
Delay: 188ms — 🟢 Good
Server: hyz.tomka.top:443
Tag: main-1-out
────────────────────
Share Link:
hy2://...@hyz.tomka.top:443/...
```

| Строка | Что означает |
|--------|--------------|
| Флаг + имя | Флаг страны (из GeoIP) + имя из #fragment |
| `Nd` рядом с именем | Сколько дней осталось до истечения (если указано в имени прокси) |
| `Type` | Протокол подключения |
| `Delay` | Задержка + вердикт: Excellent (<150ms), Good (<300ms), Acceptable (<400ms), High/Very high |
| `Server` | IP или домен сервера + порт |
| `Tag` | Внутренний тег sing-box |
| `Share Link` | Полная ссылка для копирования/передачи |

| Кнопка | Действие |
|--------|----------|
| ✅ Switch / ✅ Active | Переключить на этот прокси вручную. Если уже активен — кнопка неактивна |
| ⏱ Test | Запустить проверку задержки для этого прокси |
| 🗑 Delete | Подтверждение → удалить прокси из UCI и перезагрузить |
| 🔬 Probe Active Outbound | Показывается только если этот прокси активен. Открывает Probe |
| ← Back | Назад к списку Outbounds |

---

## 🌐 Single URL Proxy `url_links_menu`

```
🌐 Single URL Proxy [main]
Active: LV-hysteria2 | 188ms — 🟢 Good

🟢 188ms  hy2://...@hyz.tomka.top:443  🗑
```

Используется в режиме `url` — одна ссылка вместо списка.

| Кнопка | Действие |
|--------|----------|
| ➕ Set URL | Заменить единственную ссылку (вводится в чат) |
| 🗑 [N] ссылка | Удалить ссылку с подтверждением |
| 🔄 Refresh | Обновить задержку |
| 🔬 Probe Active Outbound | Запустить Probe если прокси активен |
| ← Back | Назад |

---

## ⚙️ Настройки Podkop `main_settings_menu`

```
⚙️ Podkop Settings [main]

Select a category to manage:
```

| Кнопка | Действие |
|--------|----------|
| 📁 Routing & Lists | Управление списками доменов/подсетей для маршрутизации |
| ⚙️ Core Settings | Основные параметры секции: режим, порты, флаги |
| 📎 Sections | Переключение между секциями podkop |
| ← Back | Вернуться в главное меню |

---

## ⚙️ Core Settings `advanced_settings`

```
⚙️ Core Settings [main]
────────────────────
Connection: proxy   💡 Proxy: route matched traffic through VPN tunnel.
Mode: urltest       💡 URLTest: sing-box auto-picks the fastest proxy.
────────────────────
Mixed Proxy: ✅ port 2080
Outbound iface: auto
────────────────────
Log: warn | Update: 1d
Bad WAN: ⚪ | Excl. NTP: ⚪
DL via Proxy: ⚪ | Disable QUIC: ⚪
```

| Строка | Что означает |
|--------|--------------|
| `Connection` | Тип подключения секции: proxy / vpn / block / exclusion |
| `Mode` | Режим выбора прокси: url / selector / urltest / outbound |
| `Mixed Proxy` | ✅/⚪ — включён ли SOCKS5-прокси на указанном порту (нужен для probe, ботовского транспорта) |
| `Outbound iface` | Исходящий сетевой интерфейс (auto = выбирается автоматически) |
| `Log` | Уровень логирования sing-box: debug / info / warn / error |
| `Update` | Интервал обновления community-листов |
| `Bad WAN` | Мониторинг «плохого» WAN (автоперезапуск при деградации) |
| `Excl. NTP` | Исключить NTP-трафик из маршрутизации (чтобы время синхронизировалось напрямую) |
| `DL via Proxy` | Скачивать community-листы через прокси |
| `Disable QUIC` | Блокировать QUIC (UDP 443) — форсировать TCP |

| Кнопка (строка 1) | Действие |
|---|---|
| `Conn: proxy` | Открыть меню выбора Connection Type (proxy / vpn / block / exclusion) |
| `🎯 Mode: urltest` | Открыть меню выбора Proxy Mode |

| Кнопка (строка 2) | Действие |
|---|---|
| `✅/⚪ Mixed Proxy` | Включить/выключить с подтверждением. При включении автоназначает порт если не задан |
| `✏️ Port: 2080` | Ввести новый номер порта Mixed Proxy |

| Кнопка (строка 3) | Действие |
|---|---|
| `🔗 Outbound: auto` | Ввести имя интерфейса (например `eth1`) или пустую строку для auto |
| `🔗 DNS` | Открыть настройки DNS |

| Кнопка (строка 4) | Действие |
|---|---|
| `🎯 URLTest` | Настройки URLTest (URL проверки, интервал, толерантность, список прокси) |
| `🔗 Resolver` | Настройки Domain Resolver |

| Кнопка (строка 5) | Действие |
|---|---|
| `📊 YACD` | Настройки YACD (веб-дашборд Clash) |
| `🟢 Autostart ON / 🔴 Autostart OFF` | Включить/выключить автозапуск podkop при загрузке роутера |

| Кнопка (строка 6) | Действие |
|---|---|
| `⚪/✅ Disable QUIC` | Переключить блокировку QUIC с подтверждением |
| `Update: 1d` | Переключить интервал обновления списков (цикл: 1h → 6h → 12h → 1d → 3d) |

| Кнопка (строка 7) | Действие |
|---|---|
| `⚪/✅ DL via Proxy` | Переключить скачивание листов через прокси с подтверждением |
| `⚪/✅ Excl. NTP` | Переключить исключение NTP с подтверждением |

| Кнопка (строка 8) | Действие |
|---|---|
| `⚪/✅ Bad WAN` | Включить/выключить мониторинг Bad WAN с подтверждением |
| `🔍 Bad WAN Details` | Детальные настройки Bad WAN (интерфейсы, задержка) |

| Кнопка (строка 9) | Действие |
|---|---|
| `Log: WARN` | Переключить уровень логирования (цикл: info → warn → error → debug) |
| `← Back` | Назад к Podkop Settings |

---

## 🎯 Proxy Mode `proxy_mode_menu`

```
🎯 Proxy Mode [main]

Current: urltest

url      — одна ссылка (proxy_string)
selector — ручной выбор активного прокси
urltest  — авто выбор по лучшему пингу
outbound — raw sing-box JSON (только через LuCI)
```

| Кнопка | Действие |
|--------|----------|
| `✅ urltest` (текущий) | Неактивна — уже выбран |
| `url / selector / outbound` | Подтверждение → переключить режим и перезагрузить podkop |
| ← Cancel | Вернуться к Core Settings без изменений |

**При переключении в `urltest` без заполненных ссылок** — предлагает кнопку клонирования ссылок из Selector.

**При переключении в `url` без `proxy_string`** — сохраняет режим в UCI, но **не перезагружает** podkop. Просит ввести ссылку. Reload произойдёт только после отправки ссылки.

---

## 🔗 DNS Settings `dns_settings`

Управление DNS-резолверами секции: тип (udp/dot/doh), сервер, bootstrap-DNS, TTL перезаписи.

---

## 🎯 URLTest Settings `urltest_settings`

```
🎯 URLTest Settings [main]

Testing URL: https://www.gstatic.com/generate_204
Check Interval: 3m
Tolerance: 50 ms
URLTest Links: 4
```

| Строка | Что означает |
|--------|--------------|
| `Testing URL` | URL для проверки задержки (должен возвращать 204) |
| `Check Interval` | Как часто URLTest обновляет задержки (3m, 180s, 1h...) |
| `Tolerance` | Допуск в ms — переключение на новый прокси только если он быстрее на X мс |
| `URLTest Links` | Количество ссылок в `urltest_proxy_links` |

| Кнопка | Действие |
|--------|----------|
| `✏️ Testing URL` | Ввести новый URL проверки |
| `✏️ Interval` | Ввести новый интервал |
| `✏️ Tolerance` | Ввести допуск в ms |
| `🔗 Manage URLTest Links` | Открыть список ссылок URLTest |
| `🔄 Clone from Selector (N)` | Скопировать все ссылки из selector_proxy_links в urltest_proxy_links |
| ← Back | Назад к Core Settings |

---

## 📁 Routing & Lists `community_lists`

Управление списками для маршрутизации трафика.

| Кнопка | Действие |
|--------|----------|
| Community Lists | Включить/выключить наборы блокировок (cloudflare, telegram, meta, russia_inside и др.) |
| Custom Domains | Ввести домены вручную (один домен на строку) |
| Remote Domain Lists | Ссылки на внешние списки доменов |
| Remote Subnet Lists | Ссылки на внешние списки подсетей (CIDR) |
| Custom Subnets | Ввести IP/CIDR вручную |
| Full Routed IPs | Конкретные IP полностью через туннель |
| 🔄 Update Lists Now | Принудительно обновить все remote-листы |

---

## 📎 Sections `sections_menu`

Список всех UCI-секций podkop (`podkop.main=section`, `podkop.antiz=section` и т.д.).
Нажатие на секцию делает её активной — все последующие настройки применяются к ней.

---

## 🤖 Bot Settings `bot_settings`

```
🤖 Bot Control Plane
────────────────────
🛡 Transport Policy: auto
💡 Auto: SOCKS5 → Fallback SOCKS → Custom → Direct → Emergency IPs.
🛡 Active Route: Podkop (SOCKS5:192.168.2.1:2080)
⏱ TG Latency: 212ms
────────────────────
Fallback Chain:
1. SOCKS5 (192.168.2.1:2080) ◀ active
2. Fallback SOCKS (socks5h://192.168.2.8:18088)
3. Custom (http://...)          ← если задан
4. Direct                       ← если transport ≠ socks
5. Emergency IPs
────────────────────
Overrides:
Custom Proxy: Not set
Bind Interface: Not set
────────────────────
Bot Uptime: 2d 5h 12m
Started: 2026-04-25 14:32:00
────────────────────
Last Command:
@Urs_Major at 2026-04-27 19:02:11
Cmd: /menu

Unauthorized Attempts:
0 attempts
```

| Строка | Что означает |
|--------|--------------|
| `Transport Policy` | auto — все тиры; socks — только SOCKS; direct — только прямое |
| `Active Route` | Текущий активный транспортный путь бота |
| `TG Latency` | RTT до api.telegram.org через текущий маршрут |
| `Fallback Chain` | Цепочка приоритетов: tier1 → tier2_N → tier3 → tier4 → tier5. `◀ active` = текущий |
| `Custom Proxy` | Ручной прокси-сервер (tier3) |
| `Bind Interface` | Привязать исходящий интерфейс бота (например `tailscale0`) |
| `Bot Uptime` | Время работы текущего экземпляра бота |
| `Last Command` | Кто и когда последний раз взаимодействовал с ботом |
| `Unauthorized Attempts` | Число попыток доступа от неавторизованных пользователей |

| Кнопка | Действие |
|--------|----------|
| `Transport: Auto` | Открыть меню выбора политики транспорта (Auto / Socks only / Direct only) |
| `Health: 60s` | Переключить интервал health-check watchdog (30 / 60 / 120 / 300 сек) |
| `🔗 Fallback SOCKS` | Управление резервными SOCKS-прокси (tier2) |
| `🧪 Test Fallback` | Проверить задержку до всех настроенных SOCKS |
| `👤 Admins` | Управление admin ID + anonymous group admins |
| `➕ Custom Proxy / 🗑 Clear Custom Proxy` | Задать или удалить кастомный прокси (tier3) |
| `➕ Bind Iface / 🗑 Unbind Iface` | Привязать или отвязать исходящий интерфейс |
| `🟢 Startup Notify` | Вкл/выкл уведомление о запуске бота |
| `🟢 Alert Notify` | Вкл/выкл алерты watchdog (падения sing-box, смена прокси и т.д.) |
| 🏠 Menu | Главное меню |

---

## 🔗 Fallback SOCKS `fallback_socks_menu`

Список резервных SOCKS5-прокси (tier2). Используются если tier1 (podkop mixed_proxy) недоступен.

Формат ввода: `socks5h://IP:PORT` — рекомендуется `socks5h` для резолвинга DNS через прокси.

| Кнопка | Действие |
|--------|----------|
| `🗑 [N] адрес` | Удалить прокси с подтверждением |
| `➕ Add Fallback SOCKS` | Ввести новый адрес в чат |
| `🔄 Re-test All` | Проверить задержку до всех fallback |
| ← Back | Назад к Bot Settings |

---

## 👤 Admins `admins_menu`

| Строка | Что означает |
|--------|--------------|
| `[primary] 123456123 🔒` | Основной admin (chat_id из UCI). Нельзя удалить |
| `[N] 987654123` | Дополнительный admin из `admin_ids` |

| Кнопка | Действие |
|--------|----------|
| `🗑 [N]` | Удалить дополнительного admin с подтверждением |
| `➕ Add Admin` | Ввести числовой User ID в чат |
| `🟢/🔴 Anon group admins` | Разрешить/запретить анонимным admin-ам группы управлять ботом |
| `🤖 Bot Info & Invite` | Показать @username бота, ID, версию и инструкцию по добавлению в группу |
| 🔄 Refresh | Обновить список |
| ← Back | Назад к Bot Settings |

---

## ℹ️ Info / Updates `cmd_info`

```
ℹ️ System Information

Hostname: AX6000
LAN IP: 192.168.2.1
Podkop: v0.7.14-r1
Sing-box: 1.10.3
Bot: v0.14.1
YACD: 🟢 Enabled - http://192.168.2.1:9090/ui
```

| Кнопка | Действие |
|--------|----------|
| `🔄 Check Podkop Update` | Проверить наличие новой версии podkop в репозитории opkg/apk |
| `🆕 Check Bot Update` | Проверить версию бота на GitHub. Показывает highlights новой версии |
| `🔄 Restart Bot` | Перезапустить бота через init.d с подтверждением |
| `💀 Restart Router` | Перезагрузить роутер — двойное подтверждение (кнопка + ввод `YES`) |
| 🏠 Menu | Главное меню |

---

## 🔄 Check Bot Update `cmd_check_update_bot`

**Если доступна новая версия:**
```
🆕 Bot Update Available!

Installed: v0.14.0
Available: v0.14.1

Probe Outbound, DNS hijack check, two-stage speed test

Full changelog →
```

**Если установлена актуальная:**
```
✅ Bot is up to date: v0.14.1

What's new in this version:
...

Full changelog →
```

| Кнопка | Действие |
|--------|----------|
| `✅ Update to vX.Y.Z` | Скачать и применить обновление бота |
| `🔄 Force Update` | Принудительно переустановить ту же версию (обходит guard) |
| `← Cancel / ← Back` | Отмена |

---

## 🔬 Probe Active Outbound `ask_probe_outbound`

Диагностирует текущий активный прокси через `mixed_proxy` SOCKS5.

**Confirm-карточка:**
```
🔬 Probe Active Outbound

Tests the currently active proxy through mixed_proxy:

• Exit IP, GeoIP, Cloudflare geo, Google hint
• Service reachability (YouTube, Telegram API, ChatGPT, Gemini, Discord)
• Throughput: 32 KB block check + 1 MB speed test

Active: LV-hysteria2 (main-1-out)

Takes 20–40 sec. Traffic ~1.3 MB.
```

**Результат:**
```
🔬 Active Outbound Probe
────────────────────
🌐 LV-hysteria2 (main-1-out) | Hysteria2
────────────────────
🗺 Exit IP: 37.128.123.123
🗺 GeoIP: LV Latvia
🏢 SIA VEESP
🗺 Cloudflare: LV
🗺 Google: LV
────────────────────
📨 Services:
YouTube        ✅ (LV)
Telegram API   ✅
ChatGPT        ✅
Claude.ai      ✅
Gemini         ✅
Discord        ✅
────────────────────
⚡ Throughput: ✅ 41.04 Mbps
⚡ Downloaded: 1.0 MB in 0.2s
```

| Строка результата | Что означает |
|-------------------|--------------|
| `Exit IP` | Публичный IP через который виден трафик |
| `GeoIP` | Страна по базе ipapi.co |
| `Org` | Организация/провайдер AS |
| `Cloudflare` | Страна по данным Cloudflare CDN (cdn-cgi/trace) |
| `Google` | Страна по внутреннему хинту Google (MgUcDb) |
| `YouTube (CC)` | ✅ — YouTube доступен и видит страну CC |
| `Telegram API` | ✅/❌ — api.telegram.org через этот прокси |
| `ChatGPT` | ✅/❌ — OpenAI ChatGPT |
| `Claude.ai` | ✅/❌ — Anthropic Claude |
| `Gemini` | ✅/❌ — Google Gemini |
| `Discord` | ✅/❌ — Discord |
| `Throughput` | ✅ быстро / 🔴 throttled (шейп РКН) / 🔴 block16k (обрыв после 16 КБ) |
| `Downloaded` | Объём скачанных данных теста + время |

**Контекстные кнопки по результату:**

| Ситуация | Кнопка |
|----------|--------|
| Прокси throttled (шейп) или block16k | `🌐 Switch Proxy` |
| URLTest режим + проблема | `⏱ Test All` |
| Telegram API заблокирован | `🤖 Bot Settings` |

| Кнопка | Действие |
|--------|----------|
| `▶ Run` | Запустить тест |
| `← Cancel / ← Back` | Отмена / назад |

---

## 🧪 Diagnostics `cmd_diagnostics`

```
🧪 Diagnostics

All actions below run active tests.
On slow routers they may take 10–30 seconds.
```

| Кнопка | Действие |
|--------|----------|
| `🔬 Probe Active Outbound` | Полный тест активного прокси (гео + сервисы + скорость) |
| `🔍 Upstream Health` | Опрос всех прокси через Clash API — результат текстовым файлом |
| `🌐 Global Check` | Запустить `podkop global_check` — тест DNS, маршрутов, связности |
| `🖥 Internal Diag` | Снимок UCI, маршрутов, nft, syslog, состояния бота |
| `📄 Support Bundle` | Полный пакет для отладки — все выше в одном файле (без токенов) |
| ← Back | Назад к Runtime Info |
| 🏠 Menu | Главное меню |

---

## 📁 Configs & Logs `cmd_files`

| Кнопка | Действие |
|--------|----------|
| `📄 sing-box config.json` | Отправить текущий config.json sing-box |
| `📄 UCI podkop config` | Отправить содержимое `/etc/config/podkop` |
| `📄 Syslog (tail 100)` | Последние 100 строк системного лога |
| `📄 Bot syslog` | Только строки podkop-bot из syslog |
| ← Back | Назад к Runtime Info |

---

## 🔔 Автоматические уведомления (watchdog)

Бот сам отправляет следующие алерты без нажатия кнопок:

| Событие | Сообщение |
|---------|-----------|
| Бот запустился | `🤖 Bot Online v0.14.1` + Host, Podkop версия, маршрут |
| sing-box остановился | `❌ VPN tunnel is down` |
| sing-box восстановился | `✅ VPN tunnel is back up` |
| tier1 SOCKS упал, tier2 держит | `⚠️ Primary SOCKS unavailable. Bot switched to fallback` |
| tier1 SOCKS восстановился | `✅ Primary SOCKS recovered` |
| Бот деградировал до Direct | `🔴 Bot on Direct connection` |
| Бот деградировал до Emergency IPs | `🔴 Bot on Emergency IPs` |
| Маршрут бота восстановлен | `✅ Bot connection restored` |
| Telegram недоступен | `⚠️ Telegram unreachable` |
| Telegram снова доступен | `✅ Telegram reachable` |
| Прокси переключился вручную | `🎯 Proxy manually switched — From / To` |
| URLTest выбрал другой прокси | `🎯 Proxy auto-switched — From / To` |
