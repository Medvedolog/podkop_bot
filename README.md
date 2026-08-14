<div align="center">

# 🤖 podkop_bot

**Роутер в кармане: управление podkop через Telegram — без SSH и без LuCI**

[![version](https://img.shields.io/badge/version-0.19.2-blue?style=flat-square)](CHANGELOG_RUS.md)
[![license](https://img.shields.io/badge/license-MIT-green?style=flat-square)](#-лицензия)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-24.x%20%7C%2025.x-00B5E2?style=flat-square&logo=openwrt&logoColor=white)](https://openwrt.org)
[![POSIX ash](https://img.shields.io/badge/POSIX%20ash-curl%20%2B%20jq-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](podkop_bot.sh)
[![Telegram](https://img.shields.io/badge/Telegram-Bot%20API-26A5E4?style=flat-square&logo=telegram&logoColor=white)](https://t.me/BotFather)

[**Установка**](#-быстрая-установка) · [Возможности](#-возможности) · [Поддержка форков](#-поддержка-форков-podkop) · [Веб-интерфейс](#-веб-интерфейс--luci-app-podkop-bot) · [История изменений](CHANGELOG_RUS.md)

</div>

---

[podkop](https://github.com/itdoginfo/podkop) — это сервис маршрутизации трафика для OpenWrt на базе sing-box. Обычно им управляют через LuCI или по SSH; этот бот даёт третий вариант — переключить outbound, поправить списки маршрутизации или снять диагностику прямо из чата, с телефона и откуда угодно.

Работает со всеми вариантами podkop и определяет нужный сам: **[original](https://github.com/itdoginfo/podkop)** (itdoginfo), **[netshift aka evolution](https://github.com/yandexru45/podkop-evolution)** (yandexru45), **[plus](https://github.com/ushan0v/podkop-plus)** (ushan0v) и **[forkop](https://github.com/ushan0v/forkop)** — преемник Podkop Plus со своим пакетом, сервисом и UCI-namespace `forkop`.

> **Forkop — что уже умеет бот.** Мониторинг и диагностика работают наравне с Plus. Нативно, прямо из Telegram, редактируются: URL подписки, действие секции (`connection`/`bypass`/`block`/`zapret`), условия секции (домены, IP, порты, устройства), каскад через другую секцию (detour), настройки источника подписки и параметры существующей URLTest. Всё остальное — то, что требует создавать или удалять дочерние секции и править правила по rule-модели, — бот пока честно показывает как есть и отправляет доделать в LuCI: писать в поля, которые backend всё равно проигнорирует, смысла нет.
>
> Вариант `forkop` проверяется раньше, чем `plus` — иначе после переезда бот принял бы новый пакет за старый. FakeIP-проверка ходит на `fakeip.podkop.fyi` (канон из исходников Forkop), но домен можно переопределить через `FAKEIP_TEST_DOMAIN`, поэтому проверяются оба. Если мигрировали с Plus на Forkop вручную, не останавливая бота, — перезапустите его: `/etc/init.d/podkop_bot restart`.

> 🖥️ **Не всё удобно делать в чате.** Для настроек бота есть отдельная LuCI-панель — **[luci-app-podkop-bot](https://github.com/Medvedolog/luci-app-podkop-bot)**: токен, admin_ids, транспорт, алерты, расписания отчётов и Runtime Info в браузере. Ставится тем же `install.sh` с флагом `--with-luci`, подробности — [ниже](#-веб-интерфейс--luci-app-podkop-bot).

> 📋 История изменений — [CHANGELOG_RUS.md](CHANGELOG_RUS.md) (English: [CHANGELOG.md](CHANGELOG.md))

---

## ✨ Возможности

```text
🛡️  Статус и управление    — podkop, sing-box, автозапуск, перезагрузка роутера
🔀  Outbounds               — список с задержкой, переключение, добавление/удаление ссылок
📋  Маршрутизация           — Service Lists, Domain/Subnet URL, My Domains/Subnets
🔧  Настройки секций        — тип, режим прокси, URLTest, DNS resolver, интерфейс
🌐  DNS и YACD              — тип DNS, сервер, bootstrap, YACD доступ и ключ
📊  Диагностика             — Status, Tunnel Health, Runtime Info, Active Probe, Support Bundle
🔔  Watchdog                — алерты sing-box, SOCKS, смены прокси, аварийные IP через DoH
🤖  Транспорт бота          — tier1–5 fallback, Fallback SOCKS, Custom Proxy, Bind Interface
👤  Администраторы          — добавление/удаление прямо из TG, анонимные группы
⬆️  Обновления              — бот и podkop из меню, Force Update, What's New карточка
📅  Ежедневный отчёт       — автоматический утренний дайджест в Telegram (время настраивается)
🗓  Еженедельный отчёт     — агрегаты за неделю: стабильность, трафик, подписка, версии, bot config
📤  Upload Bot Script      — загрузка и установка бота прямо через Telegram (без GitHub)
🔕  Тихие часы            — подавление watchdog-алертов в заданном временном диапазоне
🖥️  Веб-интерфейс (LuCI)   — настройка бота и удобный Runtime Info через luci-app-podkop-bot
```

**Только на Podkop Plus:**

```text
🔬  URLTest Filters         — фильтрация outbounds по стране и regex
📊  Трафик подписки         — «18.5 GB / ∞ · exp 28.08» в карточке секции
⚙️  Zapret / ByeDPI         — статус, вкл/выкл, редактирование стратегии с валидацией
🔗  Ручные ссылки           — добавление вручную в subscription-секцию (сосуществуют с подпиской)
🔌  Close Connections       — сброс всех соединений через Clash API
🖧  Server Instances        — live статус серверных инстансов (VLESS, VMess, Trojan, SOCKS, Hysteria2, MTProto, Tailscale)
```

---

## 🗺️ Главное меню

```text
🏠 Menu
├── 📊 Status
├── 🔀 Outbounds
├── 📋 Routing & Lists
├── ⚙️ Section Settings
├── 🌍 DNS & YACD
├── 🔧 Bad WAN
├── 🔧 Maintenance
│   ├── ⬆️ Update Bot / Force Update
│   ├── ⬆️ Update Podkop
│   ├── 🔁 Reboot Router
│   └── 🔌 Runtime Info → Diagnostics
├── 🖧 Server Instances (Plus)
└── ⚙️ Bot Settings
    ├── 🤖 Transport Policy
    ├── 📡 Fallback SOCKS
    ├── 📅 Daily Report
    ├── 🗓 Weekly Report
    ├── 🔕 Quiet Hours
    ├── 🔔 Broadcast Alerts / RAM Alert
    ├── 👤 Admins
    └── 🔗 Bind Interface
```

> Постоянная навигация `🏠 Menu | 📊 Status` доступна в любой момент, включая watchdog-алерты.

---

## 🔀 Поддержка форков podkop

| Функция | original | evolution / netshift | plus | forkop |
|---------|:--------:|:--------------------:|:----:|:------:|
| Управление сервисом (старт/стоп/reload) | ✅ | ✅ | ✅ | ✅ |
| Outbound Selector — просмотр и переключение | ✅ | ✅ | ✅ | ✅ |
| Добавление / удаление ссылок | ✅ | ✅ | ✅ | 👁 read-only |
| Single URL (proxy_string) | ✅ | ✅ | ✅ | 👁 read-only |
| Subscription URL (просмотр, замена) | ❌ | ✅ | ✅ | ✅ дочерние секции |
| Ручные ссылки в subscription-секции | ❌ | ❌ | ✅ | 👁 read-only |
| Действие секции (туннель/обход/блок/DPI) | ✅ | ✅ | ✅ | ✅ |
| URLTest Filters (страна, regex) | ❌ | ❌ | ✅ | ❌ до проверки на железе |
| Трафик и срок подписки | ❌ | ❌ | ✅ | ✅ |
| Zapret / ByeDPI секции | ❌ | ❌ | ✅ | ✅ |
| Zapret2 секции (своё меню) | ❌ | ❌ | ❌ | ❌ в планах |
| Close All Connections | ❌ | ❌ | ✅ | ✅ |
| Service Lists (готовые наборы) | ✅ | ✅ | ✅ | ✅ |
| Domain/Subnet List URLs | ✅ | ✅ | ✅ | ✅ |
| My Domains / My Subnets | ✅ | ✅ | ✅ | 👁 read-only |
| Переключение режима Selector ↔ URLTest | ✅ | ✅ | ✅ | 👁 read-only |
| Настройки URLTest (существующей) | ✅ | ✅ | ✅ | ✅ редактор child |
| Настройки DNS-резолвера / интерфейсов | ✅ | ✅ | ✅ | 👁 read-only |
| Условия секции (домены/IP/порты/устройства) | ❌ | ❌ | ❌ | ✅ |
| Каскад через другую секцию (detour) | ❌ | ❌ | ❌ | ✅ |
| Настройки источника подписки (интервал и пр.) | ❌ | ❌ | ❌ | ✅ |
| Rule Sets (rule_set, rule_set_with_subnets) | ❌ | ❌ | 👁 только просмотр | ❌ пока нет |
| Версии zapret / byedpi в Status | ❌ | ❌ | ✅ | ✅ |
| Версия Zapret2 в Maintenance | ❌ | ❌ | ✅ | ✅ |
| Server Instances (live статус серверов) | ❌ | ❌ | ✅ | ✅ |
| Ежедневный отчёт | ✅ | ✅ | ✅ | ✅ |
| Watchdog и Tunnel Health | ✅ | ✅ | ✅ | ✅ |
| Diagnostics / Support Bundle | ✅ | ✅ | ✅ | ✅ |
| NetShift selector_text / urltest_text | ❌ | 👁 read-only | ❌ | ❌ |
| NetShift multi-subscription URL (list) | ❌ | ✅ | ❌ | ❌ |


> **Forkop.** Мониторинг и диагностика — наравне с Plus. Подписки бот правит нативно, через дочерние секции (`config subscription_url`), действие секции пишет в `action`. Значок 👁 означает, что операция требует создать или удалить дочернюю секцию либо правило Forkop: такие вещи бот показывает как есть и отправляет в LuCI. Записывать в поля, которые backend проигнорирует, — значит соврать об успехе, поэтому бот так не делает.

> **NetShift.** Базовое управление поддерживается целиком. Расширенные параметры (`enable_ipv6`, `block_doh`, `global_proxy`, `dns_via_outbound`, режимы `selector_text`/`urltest_text`) показываются только на чтение — править их нужно в LuCI. При обновлении с podkop-evolution на NetShift бот переключает runtime сам, вмешиваться не нужно.

---

## 🚀 Быстрая установка

```sh
wget -O /tmp/install_podkop_bot.sh https://raw.githubusercontent.com/Medvedolog/podkop_bot/main/install.sh
ash /tmp/install_podkop_bot.sh
```

Установщик сам разберётся, какой вариант podkop стоит на роутере (original / evolution / netshift / plus / forkop), доставит зависимости (`curl`, `jq`) и предложит один из **четырёх режимов**:

1. **Update** — обновить скрипт, сохранить конфиг
2. **Reinstall** — переустановить с новыми настройками
3. **Exit** — выйти без изменений
4. **Uninstall** — полное удаление бота (двойное подтверждение: `YES` → `REMOVE`)

### 🌐 Установка за блокировками

Если провайдер режет GitHub, установщик сам предложит ввести прокси и скачает через него бота и зависимости. Принимается HTTP-прокси (`http://host:port`); SOCKS — только после того, как `curl` уже встал, раньше просто нечем его использовать. Прокси живёт ровно столько, сколько работает установщик: ни в UCI, ни в системные файлы он не попадает.

### 🤖 Unattended-режим (для luci-app и скриптов)

```sh
ash install.sh --unattended \
               --action install|update|uninstall|status|check \
               --config /tmp/podkop_bot_install.json \
               --lang en|ru
```

Предназначен для вызова из rpcd-бэкенда luci-app без TTY. Конфиг передаётся JSON-файлом (chmod 600), не через аргументы командной строки. `--action status` возвращает машиночитаемый JSON с версиями, вариантом podkop и состоянием сервиса.

Структурированные exit-коды:

| Код | Значение |
|-----|----------|
| 0   | Успех |
| 10  | Installer уже запущен (lock) |
| 11  | Не OpenWrt |
| 12  | Отсутствует обязательное поле конфига |
| 13  | Невалидный JSON конфига |
| 14  | Установка зависимостей не удалась |
| 15  | Скачивание файла не удалось |
| 16  | Запись UCI не удалась |
| 17  | Токен бота отклонён Telegram |
| 18  | Запуск сервиса не удался (бот мёртв после старта) |

### 🔄 Безопасное обновление с откатом

Обновление удалённого роутера — это всегда риск остаться без связи с ним. Поэтому при обновлении (`--action update` или режим 1) установщик действует так:

1. Качает новый скрипт во временный файл `/tmp/podkop_bot.new`
2. Проверяет синтаксис (`ash -n`) — если провайдер подсунул вместо скрипта страницу-заглушку, она не поедет в систему
3. Делает резервную копию текущего бинаря
4. Атомарно подменяет файл и перезапускает сервис
5. Если новая версия не стартовала — сам возвращает предыдущую

### 🖥️ Веб-интерфейс — luci-app-podkop-bot

Вбивать длинный токен и списки admin_ids с телефона — удовольствие ниже среднего. Для таких задач есть отдельный пакет LuCI: настройки бота (токен, admin_ids, транспорт, алерты, расписания отчётов) и Runtime Info — в обычной веб-панели роутера, с нормальной клавиатурой.

Репозиторий: **https://github.com/Medvedolog/luci-app-podkop-bot**

Ставится тем же `install.sh`: после установки или обновления бота он сам спросит, нужен ли веб-интерфейс. В unattended-режиме вопрос пропускается флагом `--with-luci`:

```sh
ash install.sh --unattended --action install --config /tmp/podkop_bot_install.json --with-luci
```

Есть и отдельное действие `update-luci` — качает и ставит последний релиз (`.ipk` для opkg, `.apk` для apk — что у роутера за пакетный менеджер, то и возьмёт). Работает в фоне, отвязавшись от родительского процесса, чтобы не повиснуть, если LuCI перезапустится прямо во время установки:

```sh
ash install.sh --unattended --action update-luci
```

---

## 📋 Требования

* OpenWrt 24.x / 25.x или ImmortalWrt
* Установленный и настроенный podkop (original, netshift/evolution, plus или forkop) 0.7.x с включённым Mixed Proxy Port
* Пакеты: `curl`, `jq` (устанавливаются автоматически)
* Токен Telegram-бота (получить у [@BotFather](https://t.me/BotFather))
* TG User ID администратора(-ов) — например через [@Getmyid_Work_Bot](https://t.me/Getmyid_Work_Bot)

---

## 📖 Подробное описание функций


### 🛡️ Управление сервисом

* Статус `podkop` и `sing-box` в реальном времени
* Запуск / остановка / перезагрузка `podkop`
* Включение / выключение автозапуска
* Обновление `podkop` до последней версии
* **Обновление самого бота** прямо из меню Maintenance (без SSH)

  * перед обновлением бот показывает доступную версию и краткий блок **What's New**
  * даёт ссылку на changelog
  * **Force Update** — принудительная переустановка текущей версии для применения патчей
  * **📤 Upload Bot Script** — загрузка `.sh` файла через Telegram как документ; валидирует shebang, `BOT_VERSION` и синтаксис (`busybox ash -n`), делает backup `.bak`, устанавливает и перезапускает. Для тестирования патчей без GitHub и роутеров за ISP-блокировками.
* **Перезагрузка роутера** с двойным подтверждением (кнопка + ввод `YES`)

### 🌐 Outbound Selector / URLTest / Subscription

* Просмотр списка outbound'ов с задержкой, типом протокола и страной (флаг)
* Переключение активного outbound
* Активный outbound выделен маркером `▶`
* Тест задержки всех outbound'ов одной кнопкой
* Добавление и удаление ссылок (`vless://`, `hy2://`, `ss://`, `trojan://`, `vmess://`, `socks5://`)
* Удаление по `server:port` — надёжно для всех протоколов
* Заголовок карточки отражает режим: **Outbound Selector**, **URLTest Outbounds** или **Subscription Outbounds**
* **Клонирование ссылок из Selector в URLTest** одной кнопкой
* Предупреждение при переключении в URLTest, если список ссылок пуст
* **Single URL Proxy** — отдельный режим для одной ссылки
* Для подписочных секций в шапке карточки: URL подписки + трафик и срок действия (Plus)

### ⚙️ Настройки секций podkop

* Переключение между секциями (`main`, `antiz` и любыми другими) с подтверждением
* **Корректная работа с несколькими секциями** — данные всегда читаются из активной секции
* Тип подключения (`proxy` / `vpn` / `block` / `direct`)
* Режим прокси (`selector` / `urltest` / `url` / `outbound`) — переключение через меню
* **Защита при переключении в URL-режим** — бот удерживает reload до получения ссылки
* **Auto-assign порта Mixed Proxy** при включении
* URLTest: testing URL, интервал проверки, допуск задержки, список ссылок
* **URLTest Filters** (только Plus): режим фильтрации, определение страны, скрытие отфильтрованных, списки исключений по стране и имени outbound
* Domain Resolver: включение, тип DNS, сервер — для каждой секции отдельно
* Outbound Interface: привязка секции к конкретному интерфейсу

### 📋 Маршрутизация и списки

* **Service Lists** — готовые наборы: `russia_inside`, `telegram`, `twitter`, `cloudflare` и др.
* **Domain List URLs / Subnet List URLs** — внешние списки по ссылке (URL на `.lst`-файл)
* **Devices → Tunnel** — устройства, чей весь трафик идёт через туннель (Fully Routed IPs)
* **Devices → Bypass** — устройства, которые ходят напрямую мимо туннеля (Excluded IPs)
* **My Domains / My Subnets** — собственные домены и подсети вручную (постраничный редактор)

### 🌍 DNS и YACD

* Тип DNS (`udp` / `doh` / `dot`), сервер, bootstrap DNS
* YACD: включение, WAN-доступ, управление секретным ключом

### 🔧 Настройки Bad WAN

* Включение мониторинга
* Список отслеживаемых интерфейсов
* Задержка перезагрузки

### 🤖 Управление транспортом бота

* **Transport Policy**: `auto` / `socks` / `direct` — с описанием рисков и подтверждением
* **Fallback-прокси** (`tier2_N`): добавление, удаление, тест доступности всех tier'ов. Формат записи: `socks5h://[user:pass@]host:port[#Имя]` — опциональные учётные данные и локальная мнемоника. Пароль маскируется везде в логах/UI/алертах (`user:***@`), в отображении используется мнемоника, если задана. Валидация формата при вводе (отдельно неверный формат и неверный порт 1-65535), дедуп по endpoint. Пробелы в мнемонике заменяются на `_`; пробелы в host/user/pass не допускаются
* Активный tier выделен маркером `◀ active`
* Custom Proxy (tier3)
* Bind Interface — привязка исходящего интерфейса бота
* **Автодобавление mixed_proxy других секций** как fallback tier'ов
* **Daily Report** — утренний дайджест в Telegram: посмотрел одно сообщение и знаешь, как роутер прожил сутки. Время отправки задаётся в `HH:MM` (по умолчанию `08:00`), включается тумблером в Bot Settings, отправить прямо сейчас можно из Maintenance → `📊 Send Daily Report Now`. Внутри: uptime, RAM и CPU; WAN, LAN и внешний IP с флагом страны; статус Telegram напрямую и через туннель; виртуальные адаптеры; режим секции и активный outbound с флагом; когда его переключали в последний раз — вручную или это сделал URLTest; рестарты sing-box; трафик за время его работы; транспорт бота с резервными каналами. На Podkop Plus добавляется URL подписки (секреты скрыты), её трафик и дата истечения.
* **Weekly Report** — та же идея, но на неделю вперёд по масштабу: не «как дела сейчас», а «что менялось». По умолчанию выключен, шлётся в воскресенье в 09:00; в день еженедельного отчёта ежедневный не дублируется. Внутри: версии файлов с mtime и sha256[:8], стабильность (uptime бота и туннеля, рестарты sing-box, переключения маршрута, статус Telegram), память (текущая, минимум за неделю и сколько раз срабатывал RAM-алерт), прирост трафика со средним за сутки, подписка Plus с предупреждением, если осталось меньше недели или израсходовано больше 80%, и снимок настроек бота. UCI: `weekly_report=0`, `weekly_report_day=7` (1=Пн…7=Вс), `weekly_report_time=09:00`.
* **Quiet Hours** — тихие часы: watchdog молчит в заданном диапазоне, в том числе через полночь (23:00–07:00). Отчёты Daily и Weekly под это правило не попадают — они придут в любом случае. UCI: `quiet_hours_enabled=0`, `quiet_hours_from=23:00`, `quiet_hours_to=07:00`.
* **Broadcast Alerts** — рассылать алерты watchdog всем администраторам из `admin_ids`. По умолчанию выключено: алерты уходят только на главный `chat_id`.
* **RAM Alert** — отдельный тумблер (по умолчанию включён): предупреждение, когда свободной памяти остаётся меньше 30 MB. Отбой приходит при 40 MB и выше, повтор — не чаще раза в час, чтобы не превращать это в спам.
* **Admins** — см. раздел ниже

### 👤 Управление администраторами

Администраторов можно добавлять и убирать прямо в Telegram — лезть в SSH и править UCI руками не нужно.

Открыть: **Bot Settings → 👤 Admins**

* **Основной admin** (`chat_id`) — отображается с 🔒, удалить нельзя
* **Дополнительные admins** — добавить User ID кнопкой **➕ Add Admin**, удалить с подтверждением
* **Anonymous group admins** — кнопка-переключатель 🟢/🔴
* **🤖 Bot Info & Invite** — `@username`, ID, версия + инструкция для группы

> После добавления бота в группу достаточно нажать **➕ Add Admin** и ввести `chat_id` группы.

### 📊 Диагностика и мониторинг

* **Status**: агрегированный диагноз (`✅ Podkop is running` / `⚠️ limited` / `❌ action required`), системная информация — Host, модель устройства, uptime, RAM, CPU, WAN + внешний IP, версии
* **Tunnel Health**: статус `sing-box`, `nftables`, режим, WAN, transport latency по tier'ам

  * два независимых TG health-чека: `TG direct` и `TG tunnel SOCKS5`
  * блок **Active outbounds by section** — задержка и TG-достижимость для каждой секции
  * **GitHub Connectivity** — проверка `api.github.com` и `raw.githubusercontent.com` напрямую (WAN) и через SOCKS с реальной задержкой; показывает можно ли получить обновления из-под блокировок
* **Runtime Info**: подключения, трафик, активный outbound, задержка, маршрут бота
* **Diagnostics** (единый хаб): Tunnel Health, Upstream Health, Global Check, Internal Diagnostics, Support Bundle, Active Probe
* **Active Outbound Probe**: полная диагностика через текущий активный outbound

  * Exit IP + GeoIP (ipapi.co + Cloudflare + Google)
  * YouTube country hint
  * Доступность сервисов: YouTube, Telegram API, ChatGPT, Claude.ai, Gemini, Discord
  * Двухэтапный тест скорости: 32 KB (детект РКН-обрыва) + 1 MB замер
* **Support Bundle**: UCI-конфиг, маршруты, nft, syslog одной кнопкой

### 🖧 Server Instances (только Plus)

* Live статус всех серверных инстансов из UCI (`type=server` секции podkop-plus)
* Поддерживаемые протоколы: **VLESS, VMess, Trojan, Shadowsocks, SOCKS, Hysteria2, MTProto (extended), Tailscale**
* Для каждого инстанса: протокол, порт, публичный хост, режим безопасности (Reality/TLS/none) + SNI, режим маршрутизации
* Статус порта: 🟢 слушает (TCP+UDP) · 🟡 включено в UCI, порт не обнаружен · ⚫ выключено
* Tailscale: статус через sing-box процесс + state directory; IP — в панели Tailscale
* Статистика соединений из Clash API (кол-во, ↓↑ трафик) при наличии
* Кнопка в главном меню видна только на Podkop Plus

### 🔔 Watchdog и алерты

* Мониторинг `sing-box` (алерт при остановке и восстановлении)
* Мониторинг SOCKS upstream с гистерезисом
* **Алерт смены прокси**: `🔀` с дебаунсом 120 сек — серия переключений группируется в одно сообщение, без спама при URLTest-флаппинге
* TG connectivity мониторинг (`direct` + `tunnel SOCKS5` + `tier2` раздельно)
* Периодическая проверка задержки всех SOCKS tier'ов
* Alerts при деградации маршрута бота на Direct или Emergency IPs
* **Аварийные Telegram IP** через DoH-discovery — список обновляется каждые 6 часов из трёх DoH-провайдеров (Cloudflare, Google, Quad9) с проверкой принадлежности AS62041; статичный список остаётся как fallback
* Постоянная навигационная клавиатура `🏠 Menu | 📊 Status` — доступна всегда, в том числе при watchdog-алертах
* **RAM watchdog alert** — срабатывает при свободной RAM < 30 MB, recovery при ≥ 40 MB, повтор раз в час. Советы: уменьшить URLTest outbounds, поднять `health_interval`, перейти на sing-box stable
* **Тихие часы** — watchdog-алерты подавляются в заданном диапазоне (`quiet_hours_enabled`, `quiet_hours_from`, `quiet_hours_to`). Overnight диапазоны поддерживаются
* **Broadcast Alerts** — при включении алерты рассылаются всем `admin_ids`

### 📡 Транспортная цепочка бота

Бот и сам сидит за теми же блокировками, что и роутер, поэтому пробивается до Telegram по цепочке — сверху вниз, до первого рабочего уровня:

```text
tier1   → Podkop SOCKS5 (основной туннель, primary proxy-секция)
tier2_N → Fallback-прокси list (socks5:// / socks5h://, опц. user:pass@ и #Имя) + авто-секции с mixed_proxy
tier3   → Custom Proxy
tier4   → Direct
tier5   → Emergency Telegram IPs (обновляются через DoH)
```

Смысл простой: если упал туннель, бот не должен упасть вместе с ним — иначе вы не узнаете, что что-то сломалось, и не сможете это починить из чата. Sticky-routing, Recovery Mode и обмен состоянием между watchdog и основным циклом держат бота на связи, пока жив хоть один уровень. Как только `podkop` поднимется, бот сам вернётся на `tier1` — в пределах одного интервала проверки, обычно за минуту.

---

## 👥 Несколько роутеров и администраторов

Если роутеров больше одного — например, дом и дача, — их удобно собрать в одну супергруппу Telegram и разговаривать со всеми в одном месте:

* каждому роутеру — свой bot token, отдельный бот на каждого
* администраторов может быть несколько: `admin_ids` пополняется через `uci add_list` или прямо из меню бота
* каждый алерт помечен префиксом `[hostname]` — сразу видно, какой роутер жалуется
* анонимные админы в группах тоже работают, включается через `ALLOW_ANON_ADMINS`

---

## 🔧 Ручная установка

```sh
# Скачать скрипт
wget -O /usr/bin/podkop_bot https://raw.githubusercontent.com/Medvedolog/podkop_bot/main/podkop_bot.sh
chmod +x /usr/bin/podkop_bot

# Настроить UCI
uci set podkop_bot.settings=settings
uci set podkop_bot.settings.bot_token="ВАШ_ТОКЕН"
uci set podkop_bot.settings.chat_id="ВАШ_CHAT_ID"
uci commit podkop_bot

# Запустить
/usr/bin/podkop_bot &
```

---

## 📁 Структура конфига UCI

```text
/etc/config/podkop_bot
├── settings.bot_token       — токен бота
├── settings.chat_id         — основной chat_id (куда слать алерты)
├── settings.admin_ids       — список user_id (через uci add_list)
├── settings.transport       — auto / socks / direct
├── settings.fallback_socks  — list socks5h://...
├── settings.custom_proxy    — кастомный прокси (tier3)
├── settings.bind_interface  — привязка к интерфейсу
├── settings.health_interval — интервал watchdog (сек, default 60)
├── settings.alert_notify    — 1/0 алерты watchdog
├── settings.startup_notify  — 1/0 уведомление при старте
├── settings.daily_report    — 1/0 ежедневный отчёт (default 0)
├── settings.daily_report_time — время отправки HH:MM (default 08:00)
├── settings.weekly_report   — 1/0 еженедельный отчёт (default 0)
├── settings.weekly_report_day — день недели 1-7 ISO (default 7=Sun)
├── settings.weekly_report_time — время отправки HH:MM (default 09:00)
├── settings.broadcast_alerts — 1/0 рассылка алертов всем admin_ids (default 0)
├── settings.ram_alert       — 1/0 алерт при RAM < 30 MB (default 1)
├── settings.quiet_hours_enabled — 1/0 тихие часы (default 0)
├── settings.quiet_hours_from — начало тихих часов HH:MM (default 23:00)
└── settings.quiet_hours_to  — конец тихих часов HH:MM (default 07:00)
```

> **Важно:** `admin_ids` добавляются именно через `uci add_list`, а не `uci set`. С `uci set` каждый следующий ID затрёт предыдущий, и в списке останется ровно один администратор.

```sh
uci add_list podkop_bot.settings.admin_ids="123456789"
uci add_list podkop_bot.settings.admin_ids="987654321"
uci commit podkop_bot
```

---

## 📂 Файлы проекта

| Файл | Описание |
|------|----------|
| `podkop_bot.sh` | Основной скрипт бота |
| `install.sh` | Установщик / обновление / удаление |
| `CHANGELOG.md` | История изменений (EN) |
| `CHANGELOG_RUS.md` | История изменений (RU) |
| `version.txt` | Актуальная версия для self-update |
| `highlights.txt` | Краткое описание новой версии для карточки обновления |

---

## ⚠️ Известные особенности

**OpenWrt 24.10.x — баг в BusyBox `tr`.**
Символьный класс `[:space:]` там сломан: вместе с пробелами он съедает букву `e` (`0x65`). Ловится на любой архитектуре, дело именно в сборке 24.10.x. Починено в `v0.13.90` — вместо класса перечисляем символы явно: `\n\r\t `.

**Podkop Plus — списочные поля UCI.**
`uci -q get` на list-полях (`subscription_urls`, `selector_proxy_links` и подобных) в BusyBox ash молча возвращает пустую строку — не ошибку, а именно пустоту, что коварнее. Бот вместо этого читает `uci show` и разбирает вывод сам; со стороны пользователя разницы никакой.

**URLTest режим** требует заполненного списка ссылок перед переключением — иначе `podkop` не запустится. Бот предупреждает и предлагает клонировать ссылки из Selector одной кнопкой.

**Single URL режим** — бот удерживает перезапуск `podkop` до получения ссылки, чтобы не уронить туннель на пустом `proxy_string`.

**Active Outbound Probe** использует текущий маршрут секции через Mixed Proxy и не переключает outbound временно. Определение страны через Google / YouTube / Cloudflare носит диагностический характер.

**Mixed Proxy без заданного порта.** Если в UCI не было `mixed_proxy_port`, а Mixed Proxy включали через бота, podkop падал с `jq: invalid JSON`. Починено в `v0.14.1`: бот сам подбирает первый свободный порт начиная с 2080.

---

## 📄 Лицензия

MIT

---

## 🙏 Благодарности

* [itdoginfo/podkop](https://github.com/itdoginfo/podkop) — за сам сервис
* [yandexru45/podkop-evolution](https://github.com/yandexru45/podkop-evolution) — за форк с поддержкой subscription URL и HWID
* [ushan0v/podkop-plus](https://github.com/ushan0v/podkop-plus) и [ushan0v/forkop](https://github.com/ushan0v/forkop) — за расширенный вариант podkop с Plus CLI и его преемника
* [VizzleTF/podkop_autoupdater](https://github.com/VizzleTF/podkop_autoupdater) — за шаблон установщика и идеи DoH-discovery транспорта
* [Davoyan/ipregion_bot](https://github.com/Davoyan/ipregion_bot) — за идеи geo/service-диагностики через прокси
* [vernette/ipregion](https://github.com/vernette/ipregion) — за идеи country/service probes и компактных сетевых проверок

---

## 🇬🇧 Summary

**podkop_bot** is a Telegram bot for remote management of [podkop](https://github.com/itdoginfo/podkop) — a sing-box-based traffic routing service for OpenWrt routers. Supports all podkop forks: [original](https://github.com/itdoginfo/podkop), [evolution/netshift](https://github.com/yandexru45/podkop-evolution), [plus](https://github.com/ushan0v/podkop-plus) and [forkop](https://github.com/ushan0v/forkop) (ushan0v) — see the [fork comparison table](#-поддержка-форков-podkop) for per-variant feature availability. On Forkop, monitoring and diagnostics are at parity with Plus, and the bot writes natively to subscription URLs, section action, section conditions, detour and subscription-source settings; edits that would require creating or removing Forkop child sections stay read-only and direct you to LuCI rather than writing to fields the backend ignores.

Provides full control without SSH or LuCI: start/stop/reload, outbound proxy switching with latency display, multi-section support, routing lists editor (Service Lists, Domain List URLs, Devices → Tunnel, Devices → Bypass), DNS and YACD settings. Plus-only extras: subscription traffic/expiry display, URLTest filters by country/regex, zapret/byedpi section management with strategy validation, manual links in subscription sections, Close All Connections.

The installer auto-detects the podkop variant, supports unattended mode (`--unattended --action install|update|uninstall|status|check --config <json>`) for [luci-app-podkop-bot](https://github.com/Medvedolog/luci-app-podkop-bot) rpcd backends with structured exit codes, a bootstrap HTTP proxy for installations behind ISP blocks, and rollback-safe updates (download → `ash -n` validate → atomic swap → auto-restore on failure). The same installer can also fetch and install luci-app-podkop-bot itself (`--with-luci` flag, or standalone via `--action update-luci`) — a LuCI web UI for bot configuration and a browser-friendly Runtime Info view, for anyone who'd rather not do everything through Telegram.

The bot maintains reachability through a 5-tier fallback transport chain (Podkop SOCKS → Fallback SOCKS list → Custom Proxy → Direct → Emergency IPs with DoH-based self-refresh every 6h from Cloudflare/Google/Quad9) with sticky routing, IPC-based recovery signalling, and automatic return to tier1 within one health interval after podkop recovers. A persistent reply keyboard (`🏠 Menu | 📊 Status`) is available at all times including during watchdog alerts.

v0.19.0 adds the **Forkop management MVP** — native writes for section conditions (domains/IPs/ports/devices), cascade **detour**, and **subscription source** settings, plus a **URLTest filter editor**, all guarded by transactional UCI writes (snapshot → commit → validate → automatic rollback on rejection). v0.19.2 is a P0 fix release: it eliminates a hang where the installer's endless prompt-filler could get stuck against a Russian-language y/n prompt during podkop self-update, and fixes UTF-8-safe truncation of country-flag emoji, mixed-proxy-auth transport on Forkop/Plus, and the FakeIP probe domain.

Full [changelog](CHANGELOG.md) available.
