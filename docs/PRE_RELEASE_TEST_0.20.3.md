# 0.20.3-dev5 — pre-release test candidate

This is a **non-stable, untagged test candidate**. It is not a confirmed hardware release. The stable `main` and existing published tags remain unchanged.

## Source pins

- podkop_bot source commit: `a50c6f82905676e86fe25a9d1da8dcd5eda69b66` (version and README); bot Git blob: `a4e7ff81bc827ab724d624acae4fe6b6b45d6e30`.
- BearGuard bundled bot: exact same Git blob, SHA256 `cd9aaa85ffc8ad6edb941be17458e9ea9c447502af963792579d35a8077bf033`.
- BearGuard package version: `0.20.3-r1` (testing only).
- Forkop 2.0 and Podkop Experimental 0.8.21 expected, with OpenWrt 24.10 / 25.12 (opkg / apk).

## Newly testable in dev5

- Per-section Podkop Experimental Mixed Proxy username and password editor. Credentials are masked in responses; Telegram receives the user's input message, so delete it from chat after the operation.
- Explicit reset removes username and password; **the proxy may then allow unauthenticated LAN connections**.
- Section identity check, byte limits, control-character rejection; transactional UCI apply with restart/recovery.
- Mock regression integrated in both projects' CI.

## Hardware acceptance — mandatory

Use a **spare router** reachable by Ethernet or independent management access. Back up `/etc/config/podkop` or `/etc/config/forkop` first.

1. Verify the exact bot version, embedded SHA256, architecture and package manager.
2. On Forkop 2.0: add, edit and delete sections, lists, devices, DNS fallback and WAN interfaces. Compare resulting UCI to LuCI. Check connectivity before and after each reload.
3. On Podkop Experimental 0.8.21: reorder DNS servers; edit domains, subnets, source memberships, IPv6, BitTorrent and per-rule Mixed Proxy. Test auth with valid and invalid credentials, including credential reset, without exposing secrets to logs or screenshots.
4. With an independent management link, inject a rejected configuration/reload; verify UCI rollback **and actual engine recovery**. Do not interrupt power during writes.
5. Exercise both opkg and apk install/upgrade paths; verify that a newer dev bot is not silently replaced by a previous stable version.
6. Check simultaneous LuCI/rpcd/Telegram editing and record the resulting UCI, events and route continuity.

## Not claimed as complete

Specialized **nested Forkop cascade editor** and **Podkop Experimental per-server cure editor** remain outside the implemented Telegram UI. Manage these in the upstream LuCI until their exact schemas and safe mutation rules have dedicated tests. This does not block a narrowly scoped **testing** candidate, but blocks claiming full parity.

**Release gate:** publish a versioned pre-release only after CI passes and test artifacts are inspected; stable `0.20.3` requires hardware acceptance.
