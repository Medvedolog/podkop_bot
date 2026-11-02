# Forkop 2.0 и Podkop Experimental 0.8.x: результаты исследования API и интеграции

**Дата:** 2026-11-02  
**Проекты:** `Medvedolog/podkop_bot` и `Medvedolog/luci-app-podkop-bearguard`  
**Статус:** заметки для dev-ветки `compat/forkop2-podkop-exp-20261102`; **не заявление о полной совместимости**.  
**Основание:** исходники upstream и полевые тесты на AX6000 (Forkop 2.0.0; бот 0.19.25-dev2/dev3).

## 1. Выводы

- Forkop 2.0 имеет **свой резидентный ubus-объект `forkop`**, публикуемый службой состояния. Он предназначен для статуса, инвентаризации UCI, журнала, ресурсов и состояния фоновых действий.
- В `ubus forkop` **нет** метода выбора сервера. Реальные прокси, групповые задержки и переключение Selector/Fallback доступны через Clash API sing-box. В Forkop предусмотрен штатный CLI-посредник `/usr/bin/forkop clash_api`: учитывает адрес контроллера и его secret, ограничивает методы allowlist.
- В Forkop 2.0 итоговый sing-box **outbound tag формируется из `section.label`**, а не из внутреннего UCI ID. Дочерние теги имеют вид `<section label>/<display name>`, включая уровни подписки и групп.
- Разделять **UCI ID**, **label**, **точный runtime tag**, **краткое имя кнопки**. Использовать оригинальный runtime tag для Clash API. Кнопку можно сокращать, сам tag — нельзя.
- Podkop Experimental (`podkop-exp`, UCI `config_version=2`) использует **`source` + `section` + `member`**, а не старый монолитный способ задания proxy в `section`.
- Количество доступных серверов нужно получать из дерева Clash-групп и учитывать листья, а не число подписок. Ошибка запроса или 401 не эквивалентны «0 прокси».
- Все изменения только в dev, никаких релизов или автослияния в `main` без тестов.

## 2. Forkop 2.0: объект ubus

Источник: [state_service.uc](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/service/state_service.uc) и [ACL LuCI](https://github.com/ushan0v/forkop/blob/main/luci-app-forkop/root/usr/share/rpcd/acl.d/luci-app-forkop.json).

`FORKOP_STATE_SERVICE_OBJECT` может переопределить имя объекта, по умолчанию оно **`forkop`**.

| Метод | Назначение | Оговорки |
|---|---|---|
| `state` | `revision`, `service`, `capabilities`, `actions` | Основной дешёвый статус. |
| `state_wait` | Долгое ожидание изменения ревизии/курсора журнала | До 15 с: не размножать запросы из Telegram polling. |
| `config` | `{"sections": [...]} ` с объектами всех типов UCI | **Может содержать токены и приватные URI.** Не выводить целиком в обычный статус. |
| `system_info` | Версии, устройство, свойства установленных пакетов | Статус, диагностика. |
| `usage` | Загрузка/ресурсы ядра | Дополняет статус. |
| `logs` | Курсор журнала | Оптимизация опроса. |
| `log_text` | Текст журнала и курсор | В отчётах нужен выбранный владельцем режим приватности. |
| `refresh` | Пересчёт состояния | **Не** restart и не применение UCI. |
| `import_config` | Проверка/стадирование импортируемой конфигурации в рамках LuCI-сессии | **Не** произвольный API `set` и не метод выбора прокси. |

Команды для локальной проверки на роутере:

```sh
ubus -v list forkop
ubus call forkop state '{}'
ubus call forkop system_info '{}'
ubus call forkop usage '{}'
# Следующая команда читает также секреты, сохранять ответ локально:
umask 077
ubus call forkop config '{}' > /tmp/forkop-config-private.json
```

Информация из `config` удобна для BearGuard: секции, названия, ссылки на дочерние объекты. Для **живого** выбора серверов одной `config` недостаточно.

Резидентный сервис использует события procd, изменения конфигурации/лок-файлов и опрос с адаптивной частотой. `state_wait` следует применять для событий, а не каждые несколько секунд запускать на каждый экран бота.

## 3. Forkop 2.0: Clash API и CLI

Источники: [clash_api.uc](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/singbox/clash_api.uc), [cli.uc](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/service/cli.uc), [LuCI clashApi.ts](https://github.com/ushan0v/forkop/blob/main/fe-app-forkop/src/forkop/methods/custom/clashApi.ts).

- Контроллер sing-box — **порт 9090**; bind выбирается runtime-конфигом и настройками YACD. Возможны `127.0.0.1`, адрес LAN или wildcard.
- `/usr/bin/forkop clash_api GET /proxies ''` — штатный локальный адаптер. В ответе обёртка `{status, body}`; `body` может быть строкой JSON. Сначала проверить status, затем разобрать body.
- `/usr/bin/forkop clash_summary` — краткие численные сведения.
- `GET /proxies` — дерево Proxy/Selector/URLTest/Fallback; `now`, `all`, `history`.
- `GET /providers/proxies` — proxy providers; `GET /connections` — соединения.
- `GET /group/<url-encoded-tag>/delay?url=...&timeout=...` — проверка задержек группы.
- **Переключение:** `PUT /proxies/<url-encoded-group>` с телом `{"name":"<exact full member tag>"}`. Предварительно убедиться, что группа и её член действительно существуют в текущем `GET /proxies`.
- После сетевого тайм-аута **не отправлять PUT повторно вслепую**: первый запрос мог успеть примениться. Повторно прочитать поле `now` и показать достоверное состояние.
- Предпочтительно использовать штатный CLI fallback, если прямое обращение к API не срабатывает из-за адреса или секрета.

Прямой доступ к API и CLI работают с исходными tag, а не с укороченными названиями кнопок.

## 4. Forkop 2.0: UCI-модель и связи

Источники: [connections.uc](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/config/connections.uc), [generator.uc](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/singbox/generator.uc), [constants.uc](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/singbox/constants.uc).

| Секция UCI | Роль |
|---|---|
| `section` | Родитель маршрута, `.name` и `label`, режим `action=connection`. |
| `connection_link` | Ручной сервер, `section=<parent>`, `name`, `uri`. |
| `subscription_url` | Подписка, `section=<parent>`, URL, tag и параметры обновления/фильтров. |
| `urltest` | Группа автоматического выбора. |
| `fallback_group`, `fallback_level` | Группа и уровни резервирования. |
| `section_interface` | Выход через сетевой интерфейс. |
| `tunnel`, `tunnel_peer` | Туннели и их дочерние данные. |
| `server`, `server_client` | Входящий сервер и подключённые клиенты, включая Mixed Proxy. |

В Forkop 2.0 Mixed Proxy живёт в `server`: `protocol=mixed`, `routing_mode=section`, `routing_section=<UCI parent ID>`. Нельзя управлять им через устаревшее `section.mixed_proxy_*`.

Разделение идентификаторов:

```text
uci_section_id       = section_3ebe13
section_label        = Section #1
selector_tag         = Section #1
full_proxy_tag       = Section #1/sub1/🇩🇪 Германия
display_proxy_name   = 🇩🇪 Германия
```

Пример показывает принцип, не универсальное имя каждой секции. По имени `section_3ebe13-out` нельзя надёжно найти Forkop 2.0 Selector.

## 5. Реальный тест AX6000: dev2 и dev3

**Факты по скриншотам пользователя, 2026-11-02:**

| Сборка | Что наблюдалось |
|---|---|
| `0.19.25-dev2` | Forkop 2.0.0 и Mixed Proxy `:2080` обнаружены, Telegram работает через SOCKS; меню показывает «0 прокси», статус — техническое `section_3ebe13-out`. |
| `0.19.25-dev3` | Список восстановлен: **38 прокси, 4 страницы**; активный сервер показывается. |
| Неисправленный UI-дефект `dev3` | Длинные кнопки `Section #1/sub1/🇩🇪 Германия`, обрезка названий; групповые записи URLTest/Fallback трудно отличить от настоящих серверов. |

**Корень первой регрессии:** сопоставление по UCI ID вместо runtime label/selector.  
**Корень визуальной проблемы:** вместо display name на кнопку отправлялся полный технический runtime tag.

### Требование к следующему dev (UX)

1. На кнопке: `[2] 🇩🇪 Германия`. Для совпадающих видимых названий: короткое уточнение подписки/группы (`🇩🇪 Германия · sub2`) или другой уникальный контекст.
2. В карточке узла: понятное имя, протокол, задержка, активность, источник; полный tag показывать по запросу.
3. Для URLTest/Selector/Fallback — своя пометка типа/иерархии: не выдавать переключаемую группу за отдельный прокси-сервер.
4. Пагинация по коротким отображаемым строкам и устойчивым индексам. Хранить индекс → **точный full tag** без обрезания, не восстанавливать tag из текста кнопки.
5. 38 реальных листовых прокси — отдельный счётчик; количество групп — отдельно. Обход `.all` защищён от циклов/дублирования.
6. Значок «доступен» ставить по валидному измерению/состоянию, а не только по наличию объекта API.
7. Прежние движки Podkop/Forkop 1.x/NetShift не должны менять поведение.

## 6. Podkop Experimental 0.8.x: отдельная UCI-схема

Источники: [Go model](https://github.com/podkop-net/podkop-experimental/blob/main/src/backend/model/model.go), [UCI sample](https://github.com/podkop-net/podkop-experimental/blob/main/podkop/files/etc/config/podkop), [build.go](https://github.com/podkop-net/podkop-experimental/blob/main/src/backend/plan/build.go).

- Пакет `podkop-exp`, общий namespace `podkop`, `settings.config_version=2`.
- `config source`: источник серверов; `type=subscription|links|json|interface`, `url` или `list link`, `label`.
- `config section`: маршрутизационное правило; `label`, `enabled`, списки/домены, `mixed_proxy_enabled`, `mixed_proxy_port`.
- `config member`: связь `section=<section ID>` + `source=<source ID>`; `role=server|fallback`, `include/exclude`, `via`.
- Sing-box встроен в Go backend; старую проверку отдельно запущенного `sing-box` и старые JSON paths использовать нельзя без проверки.
- Clash API — порт `9090`, обычно loopback. Фактические runtime tag и состояние выбираются по API, а не напрямую по полям `source`.
- Обновление `podkop-exp` может требовать согласия на удаление конфликтующих пакетов; Telegram-обновления без подтверждения недопустимы.

**Не смешивать адаптеры:** Forkop 2 `connection_link/subscription_url/server` и Podkop-exp `source/member` — разные модели.

## 7. Приватность и права администратора Telegram

Владелец роутера с root-доступом и подтверждённый администратор бота могут быть **одним лицом**, поэтому не нужно искусственно запрещать ему читать свои серверы/полные URI/подписки.

Но Telegram — удалённый сервис хранения сообщений и доставки уведомлений; root-доступ на роутере не делает историю переписки локальной и безопасной. Рекомендуемая политика:

- **Личный чат с явным разрешённым admin ID:** штатные карточки — компактные; действие «Полные данные»/«Показать URI» — доступны по **явному запросу** администратора. Предупредить о появлении данных в истории Telegram.
- **Группы:** никогда автоматически не отправлять секреты, даже если действие инициировано администратором. При запросе направлять в личный чат.
- **Отчёт диагностики:** переключатель «обычный/полный». Полный — по явному подтверждению, желательно личным сообщением или локальным файлом с коротким сроком хранения.
- **Логи и фоновые алерты:** без авторизационных токенов, passwords, UUID/ключей и полных подписочных URL по умолчанию.
- **Внутренняя работа:** URI, UUID, selector tag и параметры подключения не маскировать и не менять. Сокрытие относится **только к пользовательскому выводу**, а не к UCI, HTTP payload или индексу выбора.

Так admin получает требуемый функционал, без обязательной публичной рассылки секретов.

## 8. Приоритеты реализации и проверок

| Приоритет | Доработка / критерий |
|---|---|
| P0 | Разделить `display_name` и `full_tag`, сократить кнопки, корректно показывать дубликаты, не повредить PUT Selector. |
| P0 | Убрать ложные «0 прокси» при 401/ошибке Clash API, сохранить fallback на `forkop clash_api`. |
| P0 | Синхронизировать standalone bot и vendored BearGuard по байтам; версии/README/контрольные суммы обновлять вместе. |
| P1 | BearGuard: read-only состояние через `ubus forkop state/config/system_info/usage` с проверкой доступности и тайм-аутом. |
| P1 | Карточки прокси по source/group, разделение URLTest, Fallback, leaf, полные данные по запросу admin в личном чате. |
| P1 | Тесты Podkop-exp: multiple source/member, fallback, include/exclude/via, выключенная секция, встроенный Go backend. |
| P2 | Переосмыслить запись UCI Forkop 2 / Podkop-exp по новым моделям с backup/rollback; не включать старые редакторы автоматически. |
| P2 | Аппаратные тесты на opkg и apk, занятый порт 2080, credentials, сохранение роутинга и откат после failed reload. |

Для воспроизводимого теста сохранить **обезличенный** вывод `ubus forkop config` + Clash `GET /proxies` (полные секреты нужны лишь при локальной проверке у владельца).

## 9. Первичные источники

- Forkop 2 [ubus service](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/service/state_service.uc)
- Forkop 2 [ACL](https://github.com/ushan0v/forkop/blob/main/luci-app-forkop/root/usr/share/rpcd/acl.d/luci-app-forkop.json)
- Forkop 2 [CLI](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/service/cli.uc)
- Forkop 2 [restricted Clash API transport](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/singbox/clash_api.uc)
- Forkop 2 [UCI model](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/config/connections.uc)
- Forkop 2 [tag generator](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/singbox/generator.uc)
- Podkop Experimental [Go UCI model](https://github.com/podkop-net/podkop-experimental/blob/main/src/backend/model/model.go)
- Podkop Experimental [UCI sample](https://github.com/podkop-net/podkop-experimental/blob/main/podkop/files/etc/config/podkop)
- Местная [сводка совместимости](COMPAT_FORKOP2_PODKOP_EXP.md)

**Ограничения:** исходники upstream на ветке `main` могут меняться. При переносе использовать схему именно установленного релиза Forkop 2.0.0 или Podkop-exp 0.8.x. Фактические тесты проведены только на одном AX6000 и только для отображения/Telegram-транспорта; полного функционального паритета ещё нет.

## 10. Уточнение: Tailscale на самом роутере через Forkop 2.0 (dev6)

В исходниках Forkop 2.0 **не одна**, а две модели Tailscale: `server.protocol=tailscale` — входящий/серверный endpoint, который регистрирует маршрутизатор в tailnet; `tunnel.kind=tailscale` — исходящий endpoint как источник маршрутизации в секции. Эти объекты используют разные поля и состояние. [Генератор native server](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/singbox/servers.uc), [генератор исходящего tunnel](https://github.com/ushan0v/forkop/blob/main/forkop/files/usr/lib/config/connections.uc).

- Проверять фактическую поддержку по `ubus call forkop state '{}'`: `.capabilities.core.known == true` и `.capabilities.core.features.tailscale.available == true`; upstream требует теги **`with_tailscale`, `with_gvisor`**. Не запускать новый процесс sing-box только ради статуса.
- Для присоединения самого роутера: `config server`, `protocol=tailscale`, `enabled=0`, `routing_mode=rules`, `tailscale_auth_key`, `tailscale_hostname`, `tailscale_control_url`. Включать только отдельным действием после создания. Identity штатно хранится в `/etc/forkop/tailscale/<UCI-server-name>/`.
- Upstream задает `advertise_exit_node: true` для native server независимо от legacy UCI-флага. Для использования роутера как Exit Node требуется разрешение администратора в Tailscale. `tailscale_accept_routes` — поле исходящего туннеля, не этого server.
- Новый BearGuard RPC adapter `podkop_bot_tailscale` должен отличать native server от outbound tunnel; возможности native server выставлять только при подтвержденной возможности ядра, при ошибках **не менять** UCI.
- Статус `registered` по наличию identity — только косвенный сигнал; для подтверждения подключения нужны Tailscale console и актуальные маршруты/подключения. Вмешательство в самостоятельный `tailscaled` требует отдельного подтверждения.
- Podkop Experimental 0.8.x **не** получает эту native-серверную схему: его Tailscale остается неподдерживаемым до отдельной реализации в Go backend.
- `dev6` содержит **первичную, не проверенную на роутере** реализацию создания/включения native Tailscale server через Telegram/BearGuard. Полный CRUD и практическое восстановление после сбоев требуют испытаний.
