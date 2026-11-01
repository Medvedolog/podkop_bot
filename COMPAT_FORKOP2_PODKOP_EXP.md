# Forkop 2 / Podkop Experimental compatibility (test branch)

## Implemented

- Detects installed `podkop-exp` via opkg/apk before treating its shared UCI namespace as stable Podkop.
- Resolves experimental package, release source and bundled Go core identity.
- Detects Forkop 2.0 using `forkop.settings.config_version` / `sing-box-forkop` evidence, before old Forkop X markers.
- Resolves Forkop 2 mixed-proxy listeners through dedicated `server` sections (`protocol=mixed`, `routing_mode=section`, `routing_section`) instead of retired `section.mixed_proxy_*` fields.
- Disables known incompatible legacy Forkop settings editors and mixed-proxy writes.
- Blocks unattended Podkop Experimental updates in Telegram: the upstream installer can request permission to remove conflicting packages.
- Avoids obsolete 10-second JSON polling on reload of the embedded Go core.

## Not yet validated

- Running on physical OpenWrt routers (both opkg and apk).
- Forkop 2 mixed servers with authentication (`server_client` records). Such tier1 connections may fail and transport falls back to direct/user-defined SOCKS.
- Full Forkop 2 editor, subscriptions and nested-child UCI updates: new model must be mapped and tested before enabling writes.
- Embedded Go core runtime/Clash API behavior on Podkop Experimental 0.8.x.

## Local checks

```sh
sh tools/check-provider-compat.sh
```

This is **not** a general-purpose upgrade script. Back up UCI before switching upstream cores.
