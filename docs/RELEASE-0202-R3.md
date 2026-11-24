## Совместимость

- **Podkop Experimental 0.8.21:** статус встроенного sing-box берётся у Podkop, а не из списка отдельных процессов. Также сохранена совместимость с 0.8.14. При недоступном ubus выводится «неизвестно», а не «остановлен».
- **Forkop 2.0:** исправлены выбор сервера в Selector/Fallback и обновление подписок. Нативный URLTest не переключается вручную.
- Диагностика больше не выгружает сырые конфиги и журналы с потенциальными секретами; данные авторизации прокси исключены из аргументов curl.

Проверено в CI и тестах с фикстурами; **на физическом роутере не проверено**. Это тестовый пререлиз, он не заменяет стабильный выпуск.

## Compatibility

- **Podkop Experimental 0.8.21:** report the embedded sing-box status from Podkop rather than searching for a standalone process. Compatibility with 0.8.14 is retained. An unavailable ubus results in “unknown”, not “stopped”.
- **Forkop 2.0:** fixes Selector/Fallback selection and subscription refresh; native URLTest is not manually switched.
- Diagnostics no longer exports raw configs and logs that may contain secrets. Proxy credentials are not passed as curl arguments.

CI and fixture checks passed; **not tested on a physical router**. This is a prerelease, not a replacement for the stable release.

### Файл / Asset

`podkop_bot-0.20.2-r3-fix.sh` — отдельный файл бота для ручного обновления существующей установки. Не запускайте этот файл как установщик: обычный `install.sh` по-прежнему скачивает стабильный бот из `main`. Если установлен BearGuard r3, отдельное обновление бота не нужно.

The standalone script is for a manual upgrade of an existing installation, not a fresh installer. The default installer still pulls the stable script from `main`. BearGuard r3 already bundles it.

[Exact source](https://github.com/Medvedolog/podkop_bot/tree/07792a0a8fe91dc446c1f00c9348a2ef0627e5f0)
