# 0.20.3-dev1: legacy functionality parity

Target: restore bot-side configuration operations for Forkop 2.0 and Podkop Experimental 0.8.21 without writing retired UCI keys.

## First increment (implemented on dev branch)

- Modern route/list editor for Forkop 2: destinations (one scalar with domains and IPs), ports, only_devices, fully_routed_ips, community_lists, rule_set, rule_set_with_subnets.
- Modern route/list editor for Podkop Experimental 0.8: user_domains, user_subnets, community_lists, only_devices, fully_routed_ips and local/remote domain/subnet files.
- Native UCI add_list / del_list, avoid reconstructing existing multi-value strings; explicit whole-field replace for Forkop destinations.
- Reject unknown keys and invalid batch inputs before making any UCI change.
- Podkop user_domains/user_subnets dynamic mode enabled when adding entries, without overwriting preexisting text-mode lists.
- Reuse existing transactional UCI backup/commit/reload/rollback.
- Old Forkop 1 and Podkop 0.7 handlers unchanged.

## Remaining before a 0.20.3 release

- Restore section action, toggle, Mixed Proxy, native 0.8 fastest/loss/balance and per-server cure controls.
- Restore global DNS, interface, excluded-IP, QUIC, IPv6, log and list-update settings using per-variant schemas.
- Add proper support for new upstream flags and device-based routing; clarify 0.8 version-dependent options.
- Expand mock tests and CI, test real OpenWrt devices for both backends.
- Preserve existing stable 0.20.2 until hardware validation; this is NOT a release.
