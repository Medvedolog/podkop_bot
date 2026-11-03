# Forkop 2 / Podkop Experimental compatibility

> **0.20.0:** эта dev-ветка слита с веткой поддержки Forkop 2.0 из 0.20.0. Запись в Forkop 2 включена для Mixed-сервера, ручных ссылок (`connection_link`), действия секции, групп Fallback, DNS, меток и порядка; остальные редакторы Forkop 2 и всё в Podkop Experimental — только чтение (см. CHANGELOG_RUS.md, v0.20.0). Ниже — исходные заметки dev-ветки.

## Implemented

- Detects installed `podkop-exp` via opkg/apk before treating its shared UCI namespace as stable Podkop.
- Resolves experimental package, release source and bundled Go core identity.
- Detects Forkop 2.0 using `forkop.settings.config_version` / `sing-box-forkop` evidence, before old Forkop X markers.
- Resolves Forkop 2 mixed-proxy listeners and `server_client` credentials through dedicated `server` sections (`protocol=mixed`, `routing_mode=section`, `routing_section`) instead of retired `section.mixed_proxy_*` fields.
- Disables known incompatible legacy Forkop settings editors and mixed-proxy writes.
- Blocks unattended Podkop Experimental updates in Telegram: the upstream installer can request permission to remove conflicting packages.
- Avoids obsolete 10-second JSON polling on reload of the embedded Go core.

## Not yet validated

- Running on physical OpenWrt routers (both opkg and apk).
- Bot resolves credentials for Forkop 2 mixed server from the first usable `server_client` record. This still requires testing on a real router; BearGuard RPC does not expose secrets in transport URLs.
- Full Forkop 2 editor, subscriptions and nested-child UCI updates: new model must be mapped and tested before enabling writes.
- Embedded Go core runtime/Clash API behavior on Podkop Experimental 0.8.x.

## Local checks

```sh
sh tools/check-provider-compat.sh
```

This is **not** a general-purpose upgrade script. Back up UCI before switching upstream cores.

## Подробное исследование API и UCI

См. [FORKOP2_PODKOP_EXP_API_RESEARCH.md](FORKOP2_PODKOP_EXP_API_RESEARCH.md): ubus, Clash API, схема Forkop 2.0 и Podkop Experimental 0.8.x, полевые результаты AX6000, UI прокси, безопасность и план регрессионных тестов.


## Dev6 (2026-11-02): нативный Tailscale-сервер Forkop 2.0

- **Две разные сущности:** `config server` + `protocol=tailscale` регистрирует сам роутер в tailnet, а `config tunnel` + `kind=tailscale` служит исходящим туннелем маршрутизации Forkop. Запрещено подменять одну другой.
- Разрешено *экспериментальное* создание native server **с `enabled=0`**, последующее включение отдельным действием Telegram/BearGuard. Требуется сборка sing-box с `with_tailscale` и `with_gvisor`, подтверждаемая через `ubus call forkop state '{}'` (`capabilities.core.features.tailscale.available`). Не запускать второй Go-процесс для опроса capabilities.
- `tailscale_auth_key`, `tailscale_hostname`, `tailscale_control_url` записываются нативно. Старые поля `tailscale_advertise_exit_node` и `tailscale_accept_routes` для этого сервера Forkop 2 **не пишутся**: ядро само объявляет возможность Exit Node, которую затем нужно одобрить в консоли Tailscale; прием маршрутов настраивается у исходящего туннеля.
- Для Podkop Experimental 0.8.x по-прежнему **запрещена запись Tailscale**: его Go backend нельзя настраивать через форкоповскую схему или внешнее overlay JSON.
- Статус различает `server.protocol=tailscale` и `tunnel.kind=tailscale`; локальный state-файл не является доказательством полноценной регистрации и связности.
- Состояние `dev6` — код и статические тесты, **реальная авторизация и выход в tailnet на OpenWrt не проверены**. Нативный мастер `server.protocol=tailscale` доступен также из standalone `.sh` бота на Forkop 2.0 при подтвержденной capability; LuCI-интеграция и расширенный RPC-статус требуют совместимого BearGuard. Другие движки по-прежнему требуют своего backend.
- Тест: `sh tools/test-forkop2-tailscale-native.sh` (в BearGuard передать путь к встроенному боту). *Старый раздел о нереализованном Tailscale CRUD выше относится к полному управлению туннелями, а не к первичному созданию native server.*
