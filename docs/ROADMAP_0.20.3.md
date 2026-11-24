# 0.20.3-dev5 — интеграция podkop_bot и BearGuard

> Черновая разработка. `main` и стабильные релизы не изменены. Без полевых тестов на маршрутизаторах сборка не считается подтверждённым стабильным релизом.

## Готово и покрыто имитационными тестами

- Восстановлены маршруты, списки, устройства, выбор серверов, управление секциями и подписками для Forkop 2.0 и Podkop Experimental 0.8.x.
- Forkop 2: `destinations`, `ports`, `only_devices`, `fully_routed_ips`, `community_lists`, `rule_set`, `rule_set_with_subnets`, действия `connection/bypass/block/dns`.
- Podkop Experimental: `user_domains`, `user_subnets`, локальные и удалённые списки, режимы `fastest/loss/balance`, Mixed Proxy (включение, порт, логин и пароль с маскировкой).
- Общие переключатели QUIC/YACD, журналы, включение секций, обновление списков и исключения маршрутизации.
- Forkop 2: редактирование списков `settings.dns_server`, `bootstrap_dns_server`, LAN `source_network_interfaces`, `routing_excluded_ips`, `badwan_monitored_interfaces` с защитой от удаления последнего WAN при активном мониторинге.
- **Podkop Experimental, dev4:** отдельное управление упорядоченными UCI-блоками `config dns_server` (добавить, полностью изменить строку `type server`, удалить, переставить выше/ниже). Поддерживаются типы `udp`, `dot`, `doh`, `provider`. Не используется скаляр `settings.dns_server` при записи; удаление последней строки заблокировано.
- **Forkop 2, dev4:** `dns_strategy`, `dns_main_fallback_strategy` и `dns_bootstrap_fallback_strategy` (`parallel/sequential`), `unmatched_dns_mode`, `dns_detour_enabled` + `dns_detour_section`, `dns_timeout`, `dns_rewrite_ttl`, `enable_output_network_interface`, `output_network_interface`, `enable_badwan_interface_monitoring`, `badwan_reload_delay`, `bittorrent_direct`.
- **Podkop Experimental, dev4:** `dns_mode`, `dns_addresses`, `dns_rewrite_ttl`, `ipv6_routing`, выходной WAN, `bittorrent`, `bittorrent_section`. Ссылки на недействующие секции отклоняются.
- IPv4, IPv6 (включая `::` и IPv4-mapped IPv6), CIDR-маски и числовые границы валидируются до записи UCI.
- Все новые операции применяются через `_fk_txn_commit_reload`: резервная копия, UCI commit, reload и попытка восстановления при отказе; отказ без успешного отката отдельно сообщается.
- CI: `tools/test-modern-0203.sh`, `test-modern-dns-0203.sh`, `test-modern-dns-rows-0203.sh`, `test-modern-advanced-0203.sh`, `test-modern-ipv6-0203.sh`, `test-installer-no-downgrade-0203.sh`, provider compatibility.
- Единое меню «Прокси»: приоритеты Forkop 2 и основные/резервные строки Podkop Experimental доступны напрямую, без отдельной модели каскадов.\n- Интеграция с BearGuard: пакетный `luci-app-podkop-bot 0.20.3-r1` содержит побайтово закреплённую версию `0.20.3-dev5` и идентичный standalone-установщик; integrity gate проверяет SHA256 и Git blob.

## Не подтверждено; до stable остаётся

- Реальные полевые испытания на Forkop 2.0 и Podkop Experimental 0.8.21, OpenWrt с `opkg` и `apk`, включая сохранение подключения после перезагрузки движка.
- Реальное восстановление сети после неуспешного reload; гонки параллельных записей LuCI, rpcd и Telegram; жизненный цикл BearGuard при переустановке.
- Отдельный редактор каскадов Forkop не планируется: уже поддерживаются штатные `fallback_group`/`fallback_level` с упорядочиванием уровней. В меню «Прокси» добавлена кнопка «Приоритеты и резерв». Для Podkop Experimental из этого же меню открываются основные и резервные `member` с перестановкой. Специализированный редактор `cure` не входит в текущий тестовый выпуск. Пароль Mixed Proxy вводится пользователем через Telegram, но не выводится обратно ботом; сообщение с секретом следует удалить из чата.
- Полная проверка DNS-адресов и интерфейсов самой платформой. Бот валидирует поддерживаемый безопасный набор форматов; наличие значения в меню не гарантирует, что движок примет конфигурацию.

## Публикация

Две связанные draft-ветки / PR:
- [podkop_bot PR #18](https://github.com/Medvedolog/podkop_bot/pull/18)
- [BearGuard PR #27](https://github.com/Medvedolog/luci-app-podkop-bearguard/pull/27)

До завершения аппаратных испытаний не сливать в `main` и не маркировать как `v0.20.3` stable.
