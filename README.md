<div align="center">

# 🤖 podkop_bot 0.19.2

**Роутер в кармане: управление podkop через Telegram — без SSH и без LuCI**

[![version](https://img.shields.io/badge/version-0.19.2-blue?style=flat-square)](CHANGELOG_RUS.md)
[![license](https://img.shields.io/badge/license-MIT-green?style=flat-square)](#-лицензия)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-24.x%20%7C%2025.x-00B5E2?style=flat-square&logo=openwrt&logoColor=white)](https://openwrt.org)
[![POSIX ash](https://img.shields.io/badge/POSIX%20ash-curl%20%2B%20jq-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](podkop_bot.sh)
[![Telegram](https://img.shields.io/badge/Telegram-Bot%20API-26A5E4?style=flat-square&logo=telegram&logoColor=white)](https://t.me/BotFather)
[![интерфейс](https://img.shields.io/badge/интерфейс-русский-C73E3A?style=flat-square)](#-главное-меню)

[**Установка**](#-быстрая-установка) · [Возможности](#-возможности) · [Поддержка форков](#-поддержка-форков-podkop) · [Веб-интерфейс](#-веб-интерфейс--luci-app-podkop-bot) · [История изменений](CHANGELOG_RUS.md)

</div>

---

[podkop](https://github.com/itdoginfo/podkop) — это сервис маршрутизации трафика для OpenWrt на базе sing-box. Обычно им управляют через LuCI или по SSH; этот бот даёт третий вариант — переключить outbound, поправить списки маршрутизации или снять диагностику прямо из чата, с телефона и откуда угодно.

Работает со всеми вариантами podkop и определяет нужный сам: **[original](https://github.com/itdoginfo/podkop)** (itdoginfo), **[netshift aka evolution](https://github.com/yandexru45/podkop-evolution)** (yandexru45), **[plus](https://github.com/ushan0v/podkop-plus)** (ushan0v) и **[forkop](https://github.com/ushan0v/forkop)** — преемник Podkop Plus со своим пакетом, сервисом и UCI-namespace `forkop`.

> 🇷🇺 **Интерфейс бота — русский.** Начиная с v0.18.x все кнопки, карточки и уведомления переведены; переключателя языка нет, английской версии интерфейса тоже. Английскими остаются только технические термины, которые переводить и не стоит: названия протоколов, поля UCI, `URLTest`, `SOCKS`, `DNS`, `YACD`, `sing-box`, `Zapret`, `ByeDPI`. Старые английские команды (`Menu`, `Status`) бот по-прежнему понимает — если у вас в чате осталась клавиатура от прежней версии, она не сломается.

> **Forkop — что уже умеет бот.** Мониторинг и диагностика работают наравне с Plus. Нативно, прямо из Telegram, редактируются: URL подписки, действие секции (`connection`/`bypass`/`block`/`zapret`), условия секции (домены, IP, порты, устройства), каскад через другую секцию (detour), настройки источника подписки и параметры существующей URLTest. Всё остальное — то, что требует создавать или удалять дочерние секции и править правила по rule-модели, — бот пока честно показывает как есть и отправляет доделать в LuCI: писать в поля, которые backend всё равно проигнорирует, смысла нет.
>
> Вариант `forkop` проверяется раньше, чем `plus` — иначе после переезда бот принял бы новый пакет за старый. FakeIP-проверка ходит на `fakeip.podkop.fyi` (канон из исходников Forkop), но домен можно переопределить через `FAKEIP_TEST_DOMAIN`, поэтому проверяются оба. Если мигрировали с Plus на Forkop вручную, не останавливая бота, — перезапустите его: `/etc/init.d/podkop_bot restart`.

> 🖥️ **Не всё удобно делать в чате.** Для настроек бота есть отдельная LuCI-панель — **[luci-app-podkop-bot](https://github.com/Medvedolog/luci-app-podkop-bot)**: токен, admin_ids, транспорт, алерты, расписания отчётов и Runtime Info в браузере. Ставится тем же `install.sh` с флагом `--with-luci`, подробности — [ниже](#-веб-интерфейс--luci-app-podkop-bot).

> 📋 История изменений — [CHANGELOG_RUS.md](CHANGELOG_RUS.md) (English: [CHANGELOG.md](CHANGELOG.md))

---

## ✨ Возможности

Названия ниже — это ровно те подписи, которые вы увидите на кнопках бота:

```text
📊  Статус                 — podkop и sing-box, устройство, память, WAN и внешний IP
🌐  Прокси                 — список с задержкой и флагом, переключение, добавление ссылок
📄  Списки и маршруты      — готовые списки, домены и подсети, «Через туннель» и «В обход»
⚙  Настройки секции       — тип подключения, режим прокси, Mixed-прокси, URLTest, DNS
🌐  Общие                  — интерфейс, интервал обновления, QUIC, NTP в обход, DNS, YACD
🧪  Диагностика            — состояние туннеля, проверка прокси и задержек, отчёт для поддержки
🔔  Уведомления о сбоях    — sing-box, SOCKS, смена прокси, аварийные IP через DoH
🤖  Настройки бота         — подключение tier1–5, резервные SOCKS, свой прокси, интерфейс
👤  Администраторы         — добавление и удаление прямо в чате, анонимные админы в группах
🔧  Обслуживание           — обновление бота и podkop, перезапуск, перезагрузка роутера
📊  Отчёт за сутки         — утренний дайджест в Telegram, время настраивается
📅  Отчёт за неделю        — стабильность, трафик, подписка и версии в одном сообщении
📤  Загрузить скрипт       — установка новой версии бота файлом через Telegram, без GitHub
🔕  Режим тишины           — уведомления о сбоях молчат в заданные часы
🖥️  Веб-интерфейс (LuCI)   — настройка бота в браузере через luci-app-podkop-bot
```

**Только на Podkop Plus и Forkop:**

```text
🔬  Фильтры URLTest        — отбор прокси по стране, имени и регулярному выражению (Plus)
📊  Трафик подписки        — «18.5 GB / ∞ · до 28.08» в карточке секции
⚙️  Zapret / ByeDPI        — статус, включение, редактирование стратегии с проверкой
🔗  Ручные ссылки          — свои ссылки в секции подписки, рядом с подписочными (Plus)
🔌  Закрыть соединения     — сброс всех соединений через Clash API
🖧  Службы                 — живой статус серверных инстансов (VLESS, VMess, Trojan,
                              SOCKS, Hysteria2, MTProto, Tailscale)
```

---

## 🗺️ Главное меню

Кнопки на главном экране идут в два столбца — так они и показаны ниже:

```text
🖥️ Управление Podkop
├─ 📊 Статус            │ 🌐 Прокси
├─ ⚙ Настройки          │ 🔄 Перезапустить
├─ 🤖 Настройки бота    │ 🛑 Остановить · 🟢 Запустить
├─ 🖧 Службы                                  ← только Plus / Forkop
└─ 🔧 Обслуживание
```

Что внутри каждого раздела:

```text
📊 Статус
└─ 🧭 Подробнее
   ├─ 🧪 Диагностика
   ├─ 📄 Файлы и журнал
   └─ 🔌 Закрыть соединения                   ← только Plus / Forkop

🌐 Прокси            ← заголовок карточки зависит от режима секции:
                        «Прокси · Selector», «Прокси · URLTest»,
                        «Прокси подписки» или «Прокси с одной ссылкой»
├─ список прокси с задержкой и флагом страны, активный помечен ▶
├─ ⚡ Проверить задержки · 🪺 Автовыбор (в режиме URLTest)
├─ ➕ Прокси · ✏ URL подписки
└─ 🧪 Диагностика

⚙ Настройки
├─ ⚙ Настройки секции   — тип подключения, режим прокси, Mixed-прокси,
│                          URLTest, DNS-резолвер, включение секции и автозапуска
│                          (на Forkop добавляются 🎯 Условия и 🔗 Через секцию,
│                           на Plus — 🔬 Фильтры URLTest)
├─ 🌐 Общие             — исходящий интерфейс, интервал обновления, QUIC,
│                          NTP в обход, DNS, YACD, контроль WAN
├─ 📎 Секции            — переключение между секциями podkop
└─ 📄 Списки и маршруты — готовые списки, домены, подсети,
                           ➡ Через туннель, ↩ В обход, свои домены и подсети

🤖 Настройки бота
├─ Подключение (Авто · SOCKS5 · Напрямую) и интервал проверки
├─ 🔗 Резервные SOCKS · 🧪 Проверить SOCKS
├─ ➕ Прокси бота · ➕ Привязать интерфейс
├─ Сообщать о запуске · о сбоях · Уведомлять всех · Контроль памяти
├─ Режим тишины · Ежедневный отчёт · Еженедельный отчёт
└─ 👤 Администраторы

🔧 Обслуживание
├─ 🐶 Обновление Podkop · 🆕 Обновление бота
├─ 📊 Отчёт за сутки · 📅 Отчёт за неделю
├─ 📤 Загрузить скрипт
├─ 🔄 Перезапустить бота
└─ 💀 Перезагрузить роутер

🧪 Диагностика          ← 📊 Статус → 🧭 Подробнее → 🧪 Диагностика
├─ 🩺 Состояние туннеля
├─ 🔬 Проверить прокси · 🪺 Проверить задержки
├─ 🌐 Проверка Podkop · 🧠 Проверка бота
└─ 📋 Отчёт для поддержки
```

> Внизу экрана всегда висит клавиатура `🏠 Меню | 📊 Статус` — она доступна в любой момент, в том числе когда пришёл алерт от watchdog.

---

## 🔀 Поддержка форков podkop

| Функция | original | evolution / netshift | plus | forkop |
|---------|:--------:|:--------------------:|:----:|:------:|
| Управление сервисом (запуск / остановка / перезапуск) | ✅ | ✅ | ✅ | ✅ |
| Список прокси и переключение (Selector) | ✅ | ✅ | ✅ | ✅ |
| Добавление и удаление ссылок | ✅ | ✅ | ✅ | 👁 только просмотр |
| Режим одной ссылки (`proxy_string`) | ✅ | ✅ | ✅ | 👁 только просмотр |
| URL подписки (просмотр, замена) | ❌ | ✅ | ✅ | ✅ дочерние секции |
| Свои ссылки в секции подписки | ❌ | ❌ | ✅ | 👁 только просмотр |
| Действие секции (туннель / обход / блок / DPI) | ✅ | ✅ | ✅ | ✅ |
| 🔬 Фильтры URLTest (страна, регулярка) | ❌ | ❌ | ✅ | ❌ до проверки на железе |
| Трафик и срок подписки | ❌ | ❌ | ✅ | ✅ |
| Секции Zapret / ByeDPI | ❌ | ❌ | ✅ | ✅ |
| Секции Zapret2 (своё меню) | ❌ | ❌ | ❌ | ❌ в планах |
| 🔌 Закрыть соединения | ❌ | ❌ | ✅ | ✅ |
| Готовые списки | ✅ | ✅ | ✅ | ✅ |
| Списки доменов и подсетей по ссылке | ✅ | ✅ | ✅ | ✅ |
| ✏ Мои домены / ✏ Мои подсети | ✅ | ✅ | ✅ | 👁 только просмотр |
| Переключение режима Selector ↔ URLTest | ✅ | ✅ | ✅ | 👁 только просмотр |
| Настройки уже созданной URLTest | ✅ | ✅ | ✅ | ✅ редактор дочерней |
| DNS-резолвер и исходящий интерфейс | ✅ | ✅ | ✅ | 👁 только просмотр |
| 🎯 Условия секции (домены / IP / порты / устройства) | ❌ | ❌ | ❌ | ✅ |
| 🔗 Через секцию — каскад (detour) | ❌ | ❌ | ❌ | ✅ |
| Настройки источника подписки (интервал и пр.) | ❌ | ❌ | ❌ | ✅ |
| Rule Sets (`rule_set`, `rule_set_with_subnets`) | ❌ | ❌ | 👁 только просмотр | ❌ пока нет |
| Версии zapret / byedpi в 📊 Статусе | ❌ | ❌ | ✅ | ✅ |
| Версия Zapret2 в 🔧 Обслуживании | ❌ | ❌ | ✅ | ✅ |
| 🖧 Службы (живой статус серверов) | ❌ | ❌ | ✅ | ✅ |
| Отчёт за сутки | ✅ | ✅ | ✅ | ✅ |
| Уведомления о сбоях и 🩺 Состояние туннеля | ✅ | ✅ | ✅ | ✅ |
| 🧪 Диагностика / 📋 Отчёт для поддержки | ✅ | ✅ | ✅ | ✅ |
| NetShift: `selector_text` / `urltest_text` | ❌ | 👁 только просмотр | ❌ | ❌ |
| NetShift: несколько URL подписки списком | ❌ | ✅ | ❌ | ❌ |


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

Вбивать длинный токен и списки admin_ids с телефона — удовольствие ниже среднего. Для таких задач есть отдельный пакет LuCI: настройки бота (токен, admin_ids, транспорт, уведомления, расписания отчётов) и сводка состояния — в обычной веб-панели роутера, с нормальной клавиатурой.

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
* **Обновление самого бота** прямо из раздела 🔧 Обслуживание (без SSH)

  * перед обновлением бот показывает доступную версию и кратко — что нового
  * даёт ссылку «Полный список изменений»
  * **🔄 Принудительно обновить** — переустановить текущую версию, если нужно применить патч
  * **📤 Загрузить скрипт** — присылаете `.sh` файлом в чат, и бот ставит его сам: проверяет shebang, `BOT_VERSION` и синтаксис (`busybox ash -n`), делает резервную копию `.bak`, устанавливает и перезапускается. Способ обкатать патч без GitHub — и единственный вариант для роутеров, которым GitHub недоступен.
* **Перезагрузка роутера** с двойным подтверждением (кнопка + ввод `YES`)

### 🌐 Прокси: Selector, URLTest и подписка

* Список прокси с задержкой, протоколом и флагом страны
* Переключение активного прокси; активный помечен маркером `▶`
* **⚡ Проверить задержки** — замер по всем прокси одной кнопкой
* Добавление и удаление ссылок (`vless://`, `hy2://`, `ss://`, `trojan://`, `vmess://`, `socks5://`)
* Удаление по паре `сервер:порт` — работает одинаково для всех протоколов
* Заголовок карточки подстраивается под режим секции: **Прокси · Selector**, **Прокси · URLTest**, **Прокси подписки** или **Прокси с одной ссылкой**
* Перенос ссылок из Selector в URLTest одной кнопкой
* При переключении в URLTest с пустым списком бот предупредит — иначе podkop не запустится
* В секциях с подпиской в шапке видны сам URL, трафик и срок действия (Plus)

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

* **Подключение**: `Авто` / `SOCKS5` / `Напрямую` — с пояснением рисков и подтверждением
* **🔗 Резервные SOCKS** (`tier2_N`): добавление, удаление и проверка доступности всех уровней. Формат записи: `socks5h://[user:pass@]host:port[#Имя]` — опциональные учётные данные и локальная мнемоника. Пароль маскируется везде в логах/UI/алертах (`user:***@`), в отображении используется мнемоника, если задана. Валидация формата при вводе (отдельно неверный формат и неверный порт 1-65535), дедуп по endpoint. Пробелы в мнемонике заменяются на `_`; пробелы в host/user/pass не допускаются
* Активный tier выделен маркером `◀ active`
* **➕ Прокси бота** — свой прокси третьим уровнем (tier3)
* **➕ Привязать интерфейс** — с какого интерфейса бот выходит наружу
* **Автодобавление mixed_proxy других секций** как fallback tier'ов
* **Ежедневный отчёт** — утренний дайджест в Telegram: посмотрел одно сообщение и знаешь, как роутер прожил сутки. Время отправки задаётся в `HH:MM` (по умолчанию `08:00`), включается тумблером в 🤖 Настройках бота, отправить прямо сейчас можно из 🔧 Обслуживание → `📊 Отчёт за сутки`. Внутри: uptime, RAM и CPU; WAN, LAN и внешний IP с флагом страны; статус Telegram напрямую и через туннель; виртуальные адаптеры; режим секции и активный outbound с флагом; когда его переключали в последний раз — вручную или это сделал URLTest; рестарты sing-box; трафик за время его работы; транспорт бота с резервными каналами. На Podkop Plus добавляется URL подписки (секреты скрыты), её трафик и дата истечения.
* **Еженедельный отчёт** — та же идея, но на неделю вперёд по масштабу: не «как дела сейчас», а «что менялось». По умолчанию выключен, шлётся в воскресенье в 09:00; в день еженедельного отчёта ежедневный не дублируется. Отправить вручную — 🔧 Обслуживание → `📅 Отчёт за неделю`. Внутри: версии файлов с mtime и sha256[:8], стабильность (uptime бота и туннеля, рестарты sing-box, переключения маршрута, статус Telegram), память (текущая, минимум за неделю и сколько раз срабатывал RAM-алерт), прирост трафика со средним за сутки, подписка Plus с предупреждением, если осталось меньше недели или израсходовано больше 80%, и снимок настроек бота. UCI: `weekly_report=0`, `weekly_report_day=7` (1=Пн…7=Вс), `weekly_report_time=09:00`.
* **Режим тишины** — уведомления о сбоях молчат в заданном диапазоне, в том числе через полночь (23:00–07:00). Отчёты за сутки и за неделю под это правило не попадают — они придут в любом случае. UCI: `quiet_hours_enabled=0`, `quiet_hours_from=23:00`, `quiet_hours_to=07:00`.
* **Уведомлять всех** — рассылать сообщения о сбоях всем администраторам из `admin_ids`. По умолчанию выключено: они уходят только на главный `chat_id`.
* **Контроль памяти** — отдельный тумблер (по умолчанию включён): предупреждение, когда свободной памяти остаётся меньше 30 MB. Отбой приходит при 40 MB и выше, повтор — не чаще раза в час, чтобы не превращать это в спам.
* **Admins** — см. раздел ниже

### 👤 Управление администраторами

Администраторов можно добавлять и убирать прямо в Telegram — лезть в SSH и править UCI руками не нужно.

Открыть: **🤖 Настройки бота → 👤 Администраторы**

* **Основной admin** (`chat_id`) — отображается с 🔒, удалить нельзя
* **Дополнительные admins** — добавить User ID кнопкой **➕ Add Admin**, удалить с подтверждением
* **Anonymous group admins** — кнопка-переключатель 🟢/🔴
* **🤖 Bot Info & Invite** — `@username`, ID, версия + инструкция для группы

> После добавления бота в группу достаточно нажать **➕ Add Admin** и ввести `chat_id` группы.

### 📊 Диагностика и мониторинг

* **📊 Статус** — общий вердикт одной строкой: `✅ Podkop работает`, `⚠️ Работает с ограничениями`, `🟡 Бот использует резервный маршрут` или `❌ Требуется действие`. Ниже — устройство и модель, uptime, RAM, CPU, WAN и внешний IP, версии.
* **🩺 Состояние туннеля** — `sing-box`, `nftables`, режим, WAN и задержка по каждому уровню транспорта

  * две независимые проверки Telegram: напрямую и через туннель SOCKS5
  * блок с активными прокси по каждой секции — задержка и доступность Telegram
  * доступность GitHub: `api.github.com` и `raw.githubusercontent.com` напрямую и через SOCKS, с реальной задержкой. Сразу видно, получится ли обновиться из-под блокировок
* **🧭 Подробнее** — соединения, трафик, активный прокси, задержка, маршрут бота
* **🧪 Диагностика** — единый хаб: 🩺 Состояние туннеля, 🔬 Проверить прокси, 🪺 Проверить задержки, 🌐 Проверка Podkop, 🧠 Проверка бота, 📋 Отчёт для поддержки
* **🔬 Проверить прокси** — полная проверка через текущий активный прокси

  * внешний IP и определение страны (ipapi.co, Cloudflare, Google)
  * подсказка по стране от YouTube
  * доступность сервисов: YouTube, Telegram API, ChatGPT, Claude.ai, Gemini, Discord
  * замер скорости в два этапа: 32 KB (ловит обрыв на старте) и 1 MB (собственно скорость)
* **📋 Отчёт для поддержки** — конфиг UCI, маршруты, nft и системный журнал одной кнопкой

### 🖧 Службы (только Plus и Forkop)

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
* **Уведомлять всех** — при включении сообщения о сбоях рассылаются всем `admin_ids`

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

> ⚠️ **The bot's interface is Russian only.** Every button, card and alert has been in Russian since v0.18.x — there is no language switch and no English UI. Only technical terms stay in English (protocol names, UCI fields, `URLTest`, `SOCKS`, `DNS`, `YACD`, `sing-box`, `Zapret`, `ByeDPI`). This documentation and the changelog are bilingual; the bot itself is not.

**podkop_bot** is a Telegram bot for remote management of [podkop](https://github.com/itdoginfo/podkop) — a sing-box-based traffic routing service for OpenWrt routers. Supports all podkop forks: [original](https://github.com/itdoginfo/podkop), [evolution/netshift](https://github.com/yandexru45/podkop-evolution), [plus](https://github.com/ushan0v/podkop-plus) and [forkop](https://github.com/ushan0v/forkop) (ushan0v) — see the [fork comparison table](#-поддержка-форков-podkop) for per-variant feature availability. On Forkop, monitoring and diagnostics are at parity with Plus, and the bot writes natively to subscription URLs, section action, section conditions, detour and subscription-source settings; edits that would require creating or removing Forkop child sections stay read-only and direct you to LuCI rather than writing to fields the backend ignores.

Provides full control without SSH or LuCI: start/stop/reload, outbound proxy switching with latency display, multi-section support, routing lists editor (Service Lists, Domain List URLs, Devices → Tunnel, Devices → Bypass), DNS and YACD settings. Plus-only extras: subscription traffic/expiry display, URLTest filters by country/regex, zapret/byedpi section management with strategy validation, manual links in subscription sections, Close All Connections.

The installer auto-detects the podkop variant, supports unattended mode (`--unattended --action install|update|uninstall|status|check --config <json>`) for [luci-app-podkop-bot](https://github.com/Medvedolog/luci-app-podkop-bot) rpcd backends with structured exit codes, a bootstrap HTTP proxy for installations behind ISP blocks, and rollback-safe updates (download → `ash -n` validate → atomic swap → auto-restore on failure). The same installer can also fetch and install luci-app-podkop-bot itself (`--with-luci` flag, or standalone via `--action update-luci`) — a LuCI web UI for bot configuration and a browser-friendly Runtime Info view, for anyone who'd rather not do everything through Telegram.

The bot maintains reachability through a 5-tier fallback transport chain (Podkop SOCKS → Fallback SOCKS list → Custom Proxy → Direct → Emergency IPs with DoH-based self-refresh every 6h from Cloudflare/Google/Quad9) with sticky routing, IPC-based recovery signalling, and automatic return to tier1 within one health interval after podkop recovers. A persistent reply keyboard (`🏠 Меню | 📊 Статус`) is available at all times including during watchdog alerts.

v0.19.0 adds the **Forkop management MVP** — native writes for section conditions (domains/IPs/ports/devices), cascade **detour**, and **subscription source** settings, plus a **URLTest filter editor**, all guarded by transactional UCI writes (snapshot → commit → validate → automatic rollback on rejection). v0.19.2 is a P0 fix release: it eliminates a hang where the installer's endless prompt-filler could get stuck against a Russian-language y/n prompt during podkop self-update, and fixes UTF-8-safe truncation of country-flag emoji, mixed-proxy-auth transport on Forkop/Plus, and the FakeIP probe domain.

Full [changelog](CHANGELOG.md) available.
