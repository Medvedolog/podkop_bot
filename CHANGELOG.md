# Changelog

---

## v0.19.9

- **Stale URLTest drafts no longer overwrite parallel LuCI changes.** Both Podkop Plus and Forkop draft/apply editors now perform an optimistic-concurrency check immediately before staging a list replacement: the draft's saved base must still match live UCI. If the list changed in LuCI or another session, Apply is blocked, the stale draft is discarded, and the user is asked to reopen the editor.
- **Podkop Plus URLTest picker from 0.19.8 is retained as the release baseline.** Countries and exact proxies use outbound metadata, draft checkboxes, a single validated reload and read-back verification; `disabled` / `exclude` / `include` / `mixed` and upstream country-detection semantics remain supported.
- **Persistent traffic statistics from 0.19.8 are retained.** RAM remains the high-frequency accumulator while `podkop_bot.stats` stores six-hour checkpoints plus Daily/Weekly baselines across router reboots; manual reports do not move scheduled windows.
- Version sources are synchronized to **0.19.9** for normal version-gated updates.

## v0.19.8

- **Podkop Plus URLTest filters now use the Forkop-style picker UX.** Countries and explicit proxies are selected with draft checkboxes and one Apply/reload. The primary source is native Plus outbound metadata (`outboundMetadata.names` / `get_outbound_metadata`), the same source used by LuCI; Clash API is fallback only. UCI lists are read back after reload for verification. All four upstream filter modes (`disabled`, `exclude`, `include`, `mixed`) are exposed, and country detection follows upstream `flag_emoji` / `country_is` semantics with `flag_emoji` as the default.
- **Traffic statistics survive router reboots.** The high-frequency accumulator remains in `/tmp`, while a dedicated `podkop_bot.stats` UCI section stores a six-hour checkpoint plus Daily/Weekly baselines and last-report timestamps. Existing RAM baselines are migrated on upgrade. Manual Daily/Weekly reports are now read-only snapshots and do not move scheduled windows; the scheduled Weekly report also closes the skipped Daily window on its report day.
- **Forkop: dedicated `action=dns` menu.** DNS routing sections no longer fall through to the generic proxy screen. The bot edits `dns_type` and `dns_server`, keeps conditions available, and deliberately leaves complex `dns_detour_*` editing to LuCI.
- **Forkop: Priority Groups MVP.** `action=connection` sections can create `priority_group` children, add country (`flag_emoji`), Direct and catch-all fallback levels, reorder levels, and toggle `pick_fastest`, `switch_to_faster_same_priority`, and `interrupt_exist_connections`.
- **Forkop: global DNS is now an ordered list.** `dns_server` and `bootstrap_dns_server` support add/delete/move operations with the same primary-to-backup ordering used by Forkop LuCI.
- **Forkop: DNS input validation now mirrors upstream `validateDNS`.** Global DNS, Bootstrap DNS and `action=dns` reject malformed host/port/path values before staging or reload; accepted forms include IPv4/IPv6, domains, optional valid ports and DoH-style paths. Plain-text DNS messages are also deleted through `CALLBACK_MSG_ID`, so the intended cleanup works for text input.
- **Forkop: `label` and `sort_by_latency`.** Section labels are read/edited and shown in the section picker; latency sorting is exposed for connection sections.
- Includes the stabilized 0.19.7 hotfix line: native URLTest exclusions, safe two-phase Tailscale enrollment with wizard recovery/custom hostname/duplicate guard, and text-input return-to-menu UX fixes.
- Scope stays intentionally compact: generic child CRUD, complex detour graphs, Rule Sets and JSON outbound editing remain in LuCI.

## v0.19.7

- **NEW: native Forkop URLTest exclusions from Telegram.** The bot now edits the
  existing `urltest` child instead of reusing Podkop Plus parent fields. The
  first practical slice supports `exclude_countries` and `exclude_outbounds`.
- Proxy choices come from `/var/run/forkop/section-cache/<section>.json` →
  `outboundMetadata.names`, the same source used by Forkop LuCI. Telegram
  callbacks carry an index rather than arbitrary proxy names, so emoji, spaces
  and long labels are safe; the picker is paginated.
- Country choices use Forkop's `detect_server_country=flag_emoji` behaviour and
  show only countries actually present among current URLTest candidates, with
  per-country counts. A non-flag detection method is never overwritten silently.
- The first exclusion promotes `filter_mode=disabled` to `exclude`. `mixed` is
  preserved and only its exclude half is changed. Writes are blocked in
  `include`, where Forkop does not apply `exclude_*`, avoiding a false-success UI.
- Every child write re-checks ownership and uses the existing Forkop
  snapshot/commit/reload/rollback transaction.
- The public version jumps directly to **0.19.7** because 0.19.4–0.19.6 had
  already existed as interim artifacts and must not be reused.

## v0.19.3

- **Diagnostics for Tailscale creation.** The bot stayed silent after the auth
  key was submitted, and three code-level fixes did not help — static analysis
  did not find the cause. The creation path now logs a breadcrumb to syslog at
  every step: dispatcher state, branch entry, message deletion, URL recovered
  from state, key length, section name, write call, transaction result.
  No behaviour change; the goal is to locate where it stops.

  To collect: submit the key, then run `logread | grep '\[ts\]' | tail -20`.

- **FIXED (critical): adding a Tailscale node could wedge the bot completely.**
  `safe_reload_podkop` called `${PODKOP_INIT} reload` with **no timeout**, and the
  bot is single-threaded: a reload that never returns stopped the polling loop
  entirely, so the bot answered no commands at all and the change could not be
  undone from chat — only over SSH. The stall source: an enabled Tailscale
  endpoint makes sing-box log in to its control server during startup, and if
  that login hangs the backend start hangs with it — while the bot's own path to
  Telegram runs through that same backend.
  - `reload` is now bounded by `timeout 120` (falling back to a direct call where
    `timeout` is unavailable). The timeout cannot fix the reload, but it hands
    control back so the bot stays reachable and can report the failure.
  - **The node is now created DISABLED.** Creation is a config-only step that does
    not touch the network. Starting it is a separate, explicit action from the
    card, with a warning that connectivity may drop.
  - The card gained an enable/disable toggle for the node.

- **FIXED: the Tailscale auth key was not deleted from the chat.** For plain text
  the dispatcher deliberately passes an EMPTY `mid` (so `send_or_edit` never tries
  to edit the user's own message), and `delete_message` silently no-ops on an
  empty argument — the deletion was a no-op. It now uses `CALLBACK_MSG_ID`, which
  carries `.message.message_id` for plain messages too.
- **FIXED: the key was written to syslog.** The audit line logged the full message
  body, so the pre-auth key persisted in the system log — which outlives the chat
  message we delete. With state `wait_ts_key` the audit log and last-command file
  now record `<secret redacted>`.
- **FIXED: silence while applying.** `_fk_txn_commit_reload` restarts the routing
  backend and this bot reaches Telegram through it (tier1 is the local mixed
  proxy), so the transport is down between reload and confirmation. An
  acknowledgement is now sent BEFORE the transaction.
- **On numbering.** The 0.19.3–0.19.5 fixes were released under separate numbers
  but never reached the repository, so they are collapsed into a single **0.19.3**.
  Note: `_ver_is_newer` requires a strictly greater version
  (`[ "$_o" = "$_n" ] && return 1`), so a router already running an interim 0.19.4
  build will NOT accept this release via the update button — install it through
  "install from local .sh file", which does not compare versions.

## v0.19.2


- **NEW: adding a Tailscale server from the bot (Forkop).** Read-only rendering
  already existed; this adds the write path. The wizard asks for the minimum —
  control-plane URL, pre-auth key, exit-node flag — and lets Forkop default the
  rest via `server_default_set_option`. The URL is asked for even though it has a
  default, because that default points at Tailscale's cloud: on a self-hosted
  control plane (Headscale, ionscale, …) silently accepting it would register the
  node with the wrong network.
  - **Gated before any write** by `singbox_supports_tailscale`, mirroring Forkop's
    `sing_box_supports_tailscale` (`singbox/runtime.uc`): an `extended` build, or
    the `with_tailscale` tag. This matters because Forkop rejects the WHOLE config
    when a tailscale section exists on an unsupported build — a blind write would
    take routing down, not merely fail to start the node. The button is hidden
    where it could not work.
  - **The key is a credential.** Its message is deleted BEFORE any validation, so
    an early return cannot leave it in the chat history, and it never reaches the
    status card, logs or diagnostics — `tailscale_auth_key` appears exactly twice
    in the source: the UCI write and a comment.
  - Key format is not validated: Headscale and ionscale keys are not `tskey-auth-*`
    and Forkop itself only requires non-empty. The URL is checked the way LuCI
    does (`validateHttpUrl`): http/https only.
  - The node card gained "exit node" and "accept routes" toggles
    (`tailscale_advertise_exit_node`, `tailscale_accept_routes`), written through
    the same snapshot/rollback transaction.
  - The confirmation says the exit node is "advertised", not "working": the
    advertisement still has to be approved on the control server, which the bot
    cannot see.

- **FIXED (P0): endless "yes" piped into the fork installer.** Updating Podkop
  from the bot fed the installer an endless `yes` stream. Verified against all
  three upstream installers: `itdoginfo/podkop` and `yandexru45/netshift` read
  stdin with a bare `read -r` and no tty check, so our stream was their answer.
  "Continue? (yes/no)" on a pre-0.7.0/0.8.0 config silently moved
  `/etc/config/<pkg>` aside and pulled the default one — the installer itself
  warns the user will have to reconfigure from scratch. "https-dns-proxy
  detected. Remove?" silently uninstalled a third-party package. NetShift's
  "Continue migration to NetShift?" removed podkop and swapped the routing
  backend whenever any podkop artifact was present. And the Russian-translation
  prompt accepts ONLY `y` or `n`: the string "yes" matched neither, hit `*)`,
  printed a hint and looped forever, appending to a log in /tmp — router RAM.
  The stream is now `n`: destructive prompts take their `*)` branch
  (`msg "Exit"; exit 1`, update aborts, nothing destroyed) and the translation
  prompt takes `n)` and continues. Routine updates prompt for nothing and are
  unaffected. `ushan0v/forkop` is unaffected either way — its prompts are
  guarded by `[ ! -t 0 ]`. `</dev/null` is not a fix: `read` returns empty at
  EOF and lands in the same `*)` branch, looping again.

- **FIXED: the country flag was mangled in the status card.** The active-proxy
  line was truncated by BYTES (`cut -c`) on a 40-byte budget. A flag such as 🇫🇮
  is 8 bytes (two 4-byte regional indicators), so the cut landed inside the
  sequence and rendered as a replacement glyph. The same byte budget also fired
  far too early — 40 bytes is only ~20 Cyrillic letters. Added `_utf8_len` /
  `_utf8_head`, which count characters and treat a regional-indicator pair as one
  indivisible unit; the limit is now 56 characters. The trailing "(tag)" is now
  stripped from the FIRST " (", because subscription tags contain their own
  parentheses and the old regex silently failed on them.
- **FIXED: local mixed-proxy authentication broke the transport.** Forkop and
  Plus can put the local mixed/SOCKS inbound behind a login and password
  (`mixed_proxy_auth_enabled`, `mixed_proxy_username`, `mixed_proxy_password` —
  verified in `luci-app-forkop/.../section.js`). Every SOCKS endpoint was built
  from ip:port only, so enabling auth in LuCI killed the Telegram transport on
  all tiers with no usable diagnosis. Credentials are now read and inserted into
  all 8 tier1 call sites and into auto-derived fallbacks, percent-encoded — a
  password containing `@`, `:`, `/` or `#` would otherwise re-split the URL.
- **FIXED: FakeIP probe domain for Forkop.** The primary was `fakeip.forkop.fyi`,
  which appears nowhere in the Forkop repository; the canonical value is
  `fakeip.podkop.fyi` (`core/constants.uc`, `singbox/constants.uc`,
  `diagnostics/runtime.uc`). The first probe therefore always missed and the
  tunnel check only passed on the fallback. The earlier claim that this was
  "verified against core/constants.uc" was wrong. Both domains are still probed,
  since `FAKEIP_TEST_DOMAIN` can override it.
- **Minor review follow-ups (no version bump — 0.19.2 was never published):**
  an empty submission in the node-prefix editor now clears `prefix_nodes`
  (previously the flag stayed `1` with an empty `node_prefix`, so the UI read
  "on" while the backend had nothing to prepend); the URLTest child name in the
  picker keyboard is escaped with `json_escape`, matching every other keyboard
  builder.

## v0.19.1

- **FIXED: the installer pointed at the relocated Podkop Plus repository.** The
  "podkop is not installed" menu (`install.sh`, `INSTALLER_VERSION` 2.6.0 →
  2.6.1) told a fresh router to install from `ushan0v/podkop-plus`, the
  repository that was renamed to `forkop`. That contradicted the installer's own
  logic (`detect_podkop_variant()` checks Forkop **before** Plus) and the bot,
  which in 0.19.0 deliberately refuses to let an "update" silently migrate a
  Plus box to Forkop. The menu now offers Forkop at
  `https://raw.githubusercontent.com/ushan0v/forkop/refs/heads/main/install.sh`.
  Detection is unchanged: an existing Podkop Plus install is still detected as
  `plus` and fully supported — only the fresh-install recommendation moved. The
  `podkop_variant_plus_line` string is kept and reworded for existing systems.

## v0.19.0

Forkop management MVP — per TZ_FORKOP_MVP, every field verified against forkop source.

- **NEW: Section conditions (Forkop).** "Условия" screen: parent lists `domain` / `ip_cidr` / `ports` / `source_ip_cidr` — view, multiline add with per-type validation, delete by index. Devices are added from the DHCP client list with one tap. The text part of conditions (`*_text`) is shown read-only (the backend merges list and text; text is edited in LuCI). Writes run in the current shell, every `add_list` is checked, commit with revert.
- **NEW: Cascade connection (Forkop).** "Через секцию": `outbound_detour_enabled` + pick `outbound_detour_section` among enabled sections with the tunnel action (current excluded), with a cycle check up to 8 hops.
- **NEW: Subscription source settings (Forkop).** A ⚙ button per source: auto-update, interval, download via proxy, metadata, node prefix. This is a whitelisted child-UPDATE of an existing section — the first slice of the CRUD layer; creating/removing sources stays in LuCI.
- **NEW: URLTest editor (Forkop).** "Настройки URLTest" instead of read-only: testing URL, interval, tolerance, interrupt-connections (canonical child option names). No create/delete/filters/Priority; with no child present, an honest "Selector mode" notice.
- **HARDENING (0.19.0 review, source-verified): transactions, ownership, validation.** Every new write goes through a transaction: snapshot `/etc/config/forkop` → commit → reload; if Forkop's validator rejects the change the config is restored from the snapshot and reloaded again — the user sees an honest failure, not "saved". Child edits verify ownership (`option section` == active section), so a stale button can't modify another section's source/URLTest. "Домены" now follow the LuCI model: a bare line = `domain_suffix`, `full:` / `keyword:` / `regex:` prefixes route to their lists. Ports — `443` or `1000-2000` (dash, 1–65535). Intervals — full sing-box duration (`1h30m`); URLTest tolerance 0–10000. Subscription "via proxy" can only be enabled together with a transport pick (both options in one txn), same for the node prefix with its text. Detour re-validates the target at write time and walks ACTIVE detours with a visited set (no 8-hop cap). Multiple URLTest children get a picker instead of a silent first. A technical failure in batch add aborts the whole batch.
- **FIXED (review 2, verified against LuCI's write path): "Conditions" moved to Forkop's canonical model.** LuCI stores domains and IPs as ONE multiline scalar (`option domain` with inline `full:`/`keyword:`/`regex:` prefixes, `option ip_cidr`) and unsets the legacy `domain_suffix`/`domain_keyword`/`domain_regex` lists and `*_text` on save. The bot previously wrote lists — the next LuCI save would have wiped them. Now reads merge scalar plus legacy leftovers, writes go to the scalar and clear legacy exactly as LuCI does; `ports` and `source_ip_cidr` remain UCI lists. The "Домены" counter covers all entry kinds.
- **FIXED: the transaction no longer claims a restore that didn't happen.** Snapshot and rollback results are now checked and distinguished: applied · commit failed (config untouched) · Forkop rejected, rollback OK · snapshot failed (nothing was attempted) · Forkop rejected and rollback failed (message asks for manual inspection).
- **FIXED: compound operations check every `uci set`.** Via-proxy + transport section, prefix + text, detour + target all go through a shared staging helper: a failure at any step drops the whole set before commit, so a half-applied intent can no longer "succeed".
- **FIXED: transport picker broke on section names containing `_`.** The callback no longer concatenates two UCI ids — it carries a row index into a temporary mapping table.
- **FIXED: strict URL validation** for the URLTest testing URL (scheme, non-empty host, no `?`/`#`/`@` in the host, port 1–65535) and validation of prefixed values (`full:` as a domain, `keyword:` charset).
- **FIXED (review 3): legacy `domain_text` no longer widens the rule.** In Forkop that field means EXACT match and LuCI prefixes it with `full:` when combining. The bot imported it bare, silently extending the rule to every subdomain. The mapping now mirrors `loadCombinedDomainText`: `domain_text` → `full:`, `domain_keyword_text` → `keyword:`, `domain_regex_text` → `regex:`, base is the `domain` scalar or `domain_suffix_text`, duplicates removed.
- **FIXED: `uci delete` is checked inside the transaction.** A failed delete of the old value used to be ignored, so the new set was appended to the old one while the bot reported success. Delete now distinguishes "option absent" from a real failure and aborts the whole operation.
- **FIXED: transaction codes reach the UI.** Every button path reports the actual status instead of a blanket "Forkop rejected". Code 4 (rollback failed) additionally sends a full message asking the user to inspect the config — previously the UI claimed a rollback that hadn't happened.
- **FIXED: the transport-picker mapping table is scoped to chat and message.** A shared file was overwritten by the next picker, so a stale button could select a different section than its own label.
- **FIXED: comments in conditions survive.** Adding entries appends to the field's raw text instead of rebuilding it from parsed values, so `#` and `//` notes are kept.
- **FIXED: an inner space is rejected, not glued.** `keyword:google ai` used to become `keyword:googleai`; only the edges are trimmed now.
- **FIXED: node prefix is no longer cut mid-UTF-8.** Under `LC_ALL=C` truncation counted bytes and could split a character; an over-long value is now rejected with a clear message.
- Rejected from the proposal: `sort_by_latency` — no such field exists in forkop (0 backend hits); the toggle would have been fake-success.

⚠ All four blocks are the bot's first writes into Forkop structures. Live-router validation is mandatory before release.

---

## v0.18.1

Polish release over the 0.18.0 RC — navigation, Forkop read-only correctness, and user-list write safety.

- **FIXED: Forkop read-only "Back" no longer loops.** Read-only warning screens now return via dedicated `nav_*` callbacks dispatched before the feature handlers and the Forkop guard, so "Back" always lands on a real parent screen instead of re-showing the same warning.
- **FIXED: read-only screens no longer claim "empty" when they don't know.** The current-config display distinguishes three states: content present → shown; confirmed empty → "empty"; caller passed nothing → no claim at all. Config values are shown via a literal block (no backslash-escape interpretation).
- **FIXED: URLTest settings on Forkop are honestly read-only.** Opening URLTest / DNS-resolver on Forkop now shows the real child-section state (or "no child — Selector mode") instead of an editable-looking parent-field screen with a misleading "won't start" warning.
- **NEW: user domains/subnets are list_type-aware (classic Podkop, NetShift).** The bot now respects the section's `user_domain_list_type` / `user_subnet_list_type`: `dynamic` → UCI list (`list user_domains`), `text` → scalar. It reads, counts, adds, deletes, and downloads through this mode, so a section set to `dynamic` in LuCI no longer shows empty or loses its list entries. Verified against itdoginfo/podkop and yandexru45/netshift sources.
- **CHANGED: user-list writes are atomic.** Add/delete of domains/subnets go through a single writer that checks every `uci add_list`/`set`/`commit` result and reverts on any failure — no partial list left behind, no false "saved" + reload on error. Out-of-range delete indices are rejected; input that's all duplicates/invalid reports "nothing added" without a needless restart.
- **FIXED: Forkop write-path guards cover the side doors.** Read-only guards on Forkop now cover the correct command names (`ask/do_del_ul_*`), the list menus and pagination, and the add/delete/download forms and state handlers — a stale or direct callback can no longer reach a legacy write on Forkop.
- **CHANGED: "Action" button renamed for clarity.** The section-action `connection` button/label is now "Туннелировать" (tunnel the traffic); the config value `connection` is unchanged. "Готовые списки" replaces the machine-translated "Сообщества".
- **FIXED: Forkop parity gaps where the variant was still compared to `plus` literally.** Each one degraded silently on Forkop: domain-list URLs were written to a legacy field that Forkop's LuCI doesn't bind (now `domain_ip_lists`, the field LuCI shows — write, count and viewer moved together); the Zapret/ByeDPI section menus and their enable toggle were unreachable on Forkop even though it ships those providers; the mode menu offered Forkop `url`/`outbound` modes it doesn't have and read the current mode from the parent flag instead of the child section.
- **FIXED: multiline IP add moved to the safe write pattern.** `wait_fully_routed_ip` / `wait_excl_ip` no longer use a pipe-subshell (which makes `uci` staging unreliable in ash): the loop runs in the current shell, every `add_list` is checked, only real additions are counted, and the commit is verified with a revert on failure — no false "added" and no needless reload.
- **FIXED: `sed -E` replaced with POSIX BRE** in proxy credential masking. BusyBox on some OpenWrt builds lacks `-E`, which made the masked address render empty in the transport chain, Tunnel Health and the startup notification.
- **FIXED (source-verified audit): Podkop Plus repository migration.** `ushan0v/podkop-plus` was renamed to `forkop`: the update check on Plus no longer reports a false "GitHub unavailable" and instead explains the migration honestly; the "Install update" button (including a stale one from old messages) refuses to run an installer that identifies itself as Forkop — an "update" can no longer silently migrate the router to a different package.
- **FIXED: global IP exclusions on Forkop are read-only.** `routing_excluded_ips` is dead in Forkop (its migration deletes the option): the screen, add form, input state and delete now show the leftover value and point to Bypass sections in LuCI instead of writing an ignored field. `fully_routed_ips` is live in Forkop and keeps working.
- **FIXED: forkop-guard side doors.** `set_dr_type_*` (DNS resolver type) added to the read-only mask; child-section discovery tolerates uci builds that quote the section type.
- **CHANGED: single source of variant environment.** The startup block duplicated `_apply_variant_env()`; startup now calls the function, so values can't drift after a same-session migration.
- **FIXED: "active section" no longer lies or restarts Podkop.** Selecting a section only ever changed the bot's menu context (a /tmp file), yet promised to "activate" it and reloaded Podkop — on Forkop that implied an activation that doesn't exist (all enabled rules run simultaneously there). It is now "Рабочая секция бота": an honest confirmation and no reload.
- **FIXED (from hardware, Plus): literal `\\n` regression in the proxy-mode card** — mode descriptions rendered with a literal `\\n` instead of a line break (introduced by the parity edit in this same version, caught on a live router).
- **FIXED: URLTest filter buttons were truncated** — two-per-row labels now fit («Страны: искл./разреш.», «Прокси: искл./разреш.»).
- **FIXED: filter/mode toggles felt frozen** — the redraw waited for the full Podkop restart (seconds on Plus); the screen now updates first, the reload runs after.
- **CHANGED: URLTest terminology unified.** "Фильтры автовыбора" → "Фильтры URLTest" (matching the screen's own title), "Автовыбор прокси" → "Автовыбор (URLTest)".
- **FIXED: two buttons shared one label.** In global settings the button opening the WAN-monitoring screen was labelled the same as the toggle — now "Настройки контроля WAN". The `bypass` label on Forkop is unified with the others.

---

## v0.18.0

Primary Russian-language RC and the new main development line. This release consolidates the fork's native Forkop model with all our fixes.

- **NEW: native Forkop child-section model.** Subscriptions and URLTest are read from Forkop's native child sections (`config subscription_url` / `config urltest`, linked via `option section '<parent>'`), not from legacy parent fields. Replacing a subscription URL edits only the selected child source without disturbing the others; multiple sources are edited individually. This replaces the previous approach of writing to the legacy parent `subscription_urls`, which Forkop only reads as a fallback.
- **CHANGED: Forkop Selector/URLTest mode switching is read-only** (directs to LuCI) instead of a fake "applied". On Forkop the mode is a native child section (`config urltest`), so a parent-field write (`proxy_config_type`/`urltest_enabled`) would be silently ignored by the backend. The read-only guard runs at the very top of the mode-switch handler, before any UCI write.
- **FIXED: Forkop FakeIP domain.** `podkop_dns_check` on Forkop now probes `fakeip.forkop.fyi` (Forkop's declared FakeIP test domain, verified against forkop 1.0.5 `singbox/constants.uc`, `core/constants.uc`, `diagnostics/runtime.uc`) in all env paths (startup + `_apply_variant_env`). Previously it used `fakeip.podkop.fyi`, causing false DNS/tunnel warnings after subscription/DNS/reload changes on Forkop.
- **FIXED: NS-01 multi-URL refusal no longer a UX dead-end.** When a Plus section has multiple subscription URLs, generic replace is refused up front — before the URL prompt and confirmation — instead of walking the user through the whole flow only to deny at the final step.
- **CHANGED: safe subscription replace is honest about what it verifies.** The post-change probe (`podkop_dns_check`) confirms the tunnel still resolves the FakeIP domain — it does not fetch the new subscription or count nodes. Messages now say so (no false "URL verified"); the reload and commit results are checked, and a rollback that itself fails reports "rollback failed, check LuCI" instead of a false "restored".
- **FIXED: weekly report detects Forkop mode via the child section.** It now uses `section_urltest_enabled` (variant-aware) instead of the raw parent `urltest_enabled`, so a Forkop section with a child URLTest is reported as URLTest, not Selector.
- **NEW: read-only diagnostics extended to Forkop.** Subscription metadata (in weekly/daily/status reports and the proxy menu), outbound link states, and Close Connections now work on Forkop via `_variant_is_plus_like` (the underlying helpers were already Forkop-aware). Action operations (URLTest filters, provider UI, list downloads) remain Plus-only pending Forkop hardware validation.
- **FIXED: bot-script upload gated on metadata before download.** Filename and size are checked before fetching; files over 2 MB are refused with a clear message rather than silently ignored (which used to leave the wait-state hanging). Restart-tolerance is preserved.
- **NEW: full Russian localization** of the bot interface.

Includes everything from v0.17.0 below (Forkop stages 1–2, fallback-proxy security, competitor features, upload/weekly fixes).

---

## v0.17.0
- **NEW: initial Forkop backend support (stage 1 — detection & mapping).** Podkop Plus is being renamed/migrated to **Forkop** (new package/service/UCI namespace: `podkop-plus` → `forkop`, `/etc/config/podkop-plus` → `/etc/config/forkop`, `/usr/bin/podkop-plus` → `/usr/bin/forkop`). This release adds `forkop` as a distinct backend variant: `_detect_podkop_variant()` now detects Forkop **before** Plus (so a migrated system with lingering podkop-plus artifacts is correctly seen as Forkop), and the variant→UCI/binary/package/repo/init mapping is applied in all three code paths (detect, `_apply_variant_env`, startup case). Forkop uses its own FakeIP test domain `fakeip.forkop.fyi` (verified against Forkop `core/constants.uc`), repo `ushan0v/forkop`, and display name "Forkop". Added `_variant_is_plus_like()` helper (Plus + Forkop share the CLI/JSON/action section model) and marked Forkop as subscription-capable.
  - **Note:** this is the foundation only. Full Forkop management (the `action=connection`/`bypass` section model, variant-aware runtime paths `/var/run/forkop` & `/etc/forkop`, migration-safe update flow, self-healing on manual user migration, and transport re-detection) lands in subsequent stages. On this release, a bot that is running during a Plus→Forkop migration should be restarted (`/etc/init.d/podkop_bot restart`) to pick up the new backend.
- **SECURITY: fallback proxy — credentials, mnemonics, masking.** `fallback_socks` entries now support optional `user:pass@` credentials and an optional local mnemonic (`#Name`). The password is never shown in logs, `ROUTE_NAME`, bot replies, alerts, the transport chain, Tunnel Health, the fallback list, delete/duplicate confirmations, or startup notify — everything routes through `_proxy_display` (mnemonic, or credential-masked endpoint `user:***@`). `curl -x` still receives the full endpoint (credentials preserved, mnemonic stripped). Interactive add via Telegram validates the new format (distinct `bad_format` vs `bad_port` errors, port 1-65535), dedups by scheme-qualified endpoint, and normalizes spaces in the mnemonic to `_` (the fallback list is stored space-separated). All user-controlled display values are HTML/JSON-escaped.
  - **Web-UI contract:** because the list is space-separated, any LuCI/web front end writing `fallback_socks` MUST apply the same rule — forbid spaces in the mnemonic or convert them to `_` — or the bot may split a `#Name with space` record into two entries.
- **FIXED: fallback proxy validation rejected whitespace only in the mnemonic, not in the endpoint.** A password/host/user containing a space (e.g. `socks5h://user:pa ss@host:1080`) previously had the space silently stripped before validation, turning `pa ss` into `pass` without telling the user. The endpoint is no longer silently altered: the validation regex now rejects any whitespace in host/user/pass, so such input is reported as an invalid format instead of quietly changing the password. (Spaces in the mnemonic are still normalized to `_`, as before.)
- **NEW: Forkop operational support (stage 2 — action model, paths, plus-like layer).** `get_section_type()` and `set_section_action()` now handle Forkop's native `action` field with the canonical `connection`/`bypass` model (plus legacy aliases `proxy|outbound|vpn` → connection, `direct|exclusion` → bypass); previously Forkop fell through to the `connection_type` branch and every section mis-read as `proxy:selector`, and writes went to a field Forkop ignores. The three CLI/JSON helpers (`_plus_has_cmd`, `_plus_json`, `_plus_sub_metadata`) now gate on `_variant_is_plus_like` so Forkop gets status/subscription/system-info. Runtime paths are variant-aware: sing-box version (`/etc/forkop/sing-box-version`), section cache & subscription metadata (`/var/run/forkop`), Tailscale state (`/etc/forkop`). `section_is_subscription` treats Forkop like Plus; DNS server/bootstrap are written as UCI lists on Forkop. This fixes the "Sing-box unknown" display and unreliable transport-section resolution on migrated boxes. (Stage 3 — live migration & self-healing — still to come.)
- **FIXED: section-freeze guard checked the UI-active section, not the bot's transport.** Freezing a section's `enabled` flag warns if it would cut the bot off from Telegram, but the guard compared against `get_active_section` (the UI-selected section) instead of `_resolve_primary_section` (the first proxy section with `mixed_proxy_enabled=1`, which actually carries the Telegram transport). If those differed (e.g. transport on `main`, UI on `warp`), freezing the real transport section produced no warning. Guard now resolves the true primary transport section.
- **FIXED: direct-speed probe could travel through the tunnel.** The optional "(direct: X Mbps)" reference measurement in the throughput probe ran `curl` without binding to WAN, so on a router with transparent (TProxy) routing it could re-enter the tunnel and report the tunnel's speed as "direct". It now forces the WAN interface (`--interface` + `--noproxy '*'`), and if the WAN interface can't be resolved it omits the direct reference entirely rather than show a potentially false comparison.
- **FIXED: multiline add results were not HTML-escaped.** The batch add of routed/excluded IPs and domains/subnets echoed each processed line back into a Telegram HTML message without escaping; a line like `<bad>` could break the markup or trigger a Telegram 400. Results are now wrapped in an escaped `<pre>` block. Stale per-process temp files are cleared before a batch.
- **FIXED: zero-section state reported as "your only section".** The sections menu used `-le 1`, so an empty/corrupt UCI config (0 sections) printed the single-section message. Zero and one are now separate states (zero points to LuCI to check the config).
- **NEW: safe subscription-URL replace with verify + rollback (NS-01).** Replacing a section's subscription URL from the bot now saves the current URL, applies the new one, reloads, and runs `podkop_dns_check`; if resolution breaks, it automatically restores the previous URL and reloads again. If a section carries **more than one** subscription source, replacement is refused (read-only, manage in LuCI) so a single-value write can't silently drop the others. Forkop/NetShift child-format subscriptions (`config subscription_url` blocks) are detected and refused with a clear message instead of a silent no-op write to the ignored parent field.
- **NEW: adopted four features from competitor bots.** Multiline add of routed/excluded IPs and domains/subnets (one entry per line, validated and de-duplicated including within the batch); universal section enable/disable toggle with a guard that warns before freezing the bot's transport section; auto-select when only one section exists (with a distinct zero-state); and a direct-speed reference in the throughput probe (WAN-bound, see above).
- **FIXED: bot-script upload via Telegram could reject a valid file after a restart.** The upload flow stored a "waiting for file" state in `/tmp`, which a bot restart (e.g. watchdog) between pressing "Upload Bot Script" and sending the file would clear — the incoming file was then refused with "use Upload first". A valid admin script (correct shebang, `BOT_VERSION`, passing syntax check) is now accepted regardless of that state; safety is unchanged (admin gate + signature + syntax check still apply).
- **FIXED: weekly report could stop sending permanently.** The single-instance lock recorded a PID and, after a restart, that PID could be reused by the bot process itself — the next run saw a "live" owner matching `podkop_bot` and returned early without ever sending, leaving the lock in place forever. Replaced with an atomic `mkdir` lock plus time-based staleness (a lock older than 5 minutes is reclaimed), so an interrupted run can't suppress future reports.
- **CHANGED: backend name shown in the bot's route label.** `ROUTE_NAME`/`LAST_ROUTE_NAME` now use the variant display name (Forkop / NetShift / Podkop Plus / Podkop) instead of a hardcoded "Podkop".

---

## v0.16.0
- **FIXED: DNS changes could be silently skipped by the reload cooldown** — `safe_reload_podkop` has a 10-second cooldown that skips a reload if one ran recently (unless called with `"force"`). DNS *server*/*bootstrap* changes already forced the reload, but DNS *protocol* (`do_dns_pr_*`, UDP/DoH/DoT), *Domain Resolver* toggle/type (`do_toggle_dr`, `set_dr_type_*`), and the *Domain Resolver server* input (`wait_dr_server`) called `safe_reload_podkop` **without** `"force"`. Sequence "change DNS server → immediately change protocol" left the second change committed to UCI but the reload skipped by cooldown: the UI showed the new value while sing-box kept running the old runtime DNS config until the next reload. All DNS write handlers now force the reload.
- **NEW: post-apply DNS verification after every DNS change (`podkop_dns_check`, Variant A — warn, no auto-rollback)** — after any DNS change (protocol, global server, bootstrap, Domain Resolver enable/type/server) the bot now runs `podkop_dns_check` (resolves `fakeip.podkop.fyi` via `127.0.0.42`, expects a `198.18.x.x` FakeIP answer proving the tunnel is routing) and, on failure, sends a warning with a Logs shortcut: the DNS change may have broken resolution — verify the server or switch back. Previously the bot confirmed only that the value was written to UCI, never that DNS still worked afterwards; a typo'd or unreachable DoH/DoT server would silently break resolution with a "saved ✅" message. The check intentionally does **not** auto-revert (it detects "tunnel not resolving," which can also be caused by an unrelated tunnel drop, not necessarily the DNS value) — the user keeps control and decides. 6-second settle delay (vs. 15s for full reload) since DNS applies faster than a full tunnel restart.
- **FIXED: traffic accumulator missed restarts where only one counter dropped** — `_traffic_accum_tick()`'s restart detection checked `downloadTotal` only; if it stayed flat across a restart (e.g. both readings near 0) while `uploadTotal` dropped, the code took the "monotonic growth" branch and subtracted a negative delta straight into `banked_ul`, silently corrupting the accumulated total. Now detects a restart if *either* counter goes backwards.
- **FIXED: `TRAFFIC_ACCUM_FILE`/`WEEKLY_TRAFFIC_BASE` writes not atomic** — both now go through `tmp+mv` instead of a direct redirect, so a power loss or crash mid-write can't leave a truncated/corrupt state file.
- **NEW: Daily Report — bot version/mtime/hash line** — same info Weekly Report already showed (`Bot: vX.X.X · mtime · hash8`), added to Daily's "🖥 Система" section.
- **FIXED: Daily Report traffic window was "time since sing-box process started", not "today"** — the traffic figure used raw Clash `downloadTotal`/`uploadTotal`, labeled "(за Xh Ym)" where X was sing-box's own process uptime (`pgrep` + `/proc/PID/stat`). Any sing-box restart during the day silently shrank the reported window and understated traffic, while the label made it look like a deliberate reporting period. Now uses a `DAILY_TRAFFIC_BASE` snapshot against the same persistent accumulator Weekly Report uses — a true ~24h delta that survives sing-box restarts, mirroring the Weekly fix from v0.15.9. Sing-box process uptime is still shown, but moved to the Tunnel section as diagnostic info, no longer mislabeling the traffic window.
- **FIXED: Daily Report `sing-box restarts (today)` count could read 0 despite an obvious restart** — was computed via `logread`, which only sees a small circular buffer; an early-morning restart could already be rotated out by evening. Switched to `SB_RESTART_LOG` (the persistent, timestamped restart log `_traffic_accum_tick()` already writes) filtered to the last 24h — same fix already applied to Weekly's restart count in v0.15.9, now applied to Daily's too.
- **FIXED: "Installation failed (exit 1)" updating podkop on a router with a leftover config from a previously-removed podkop install** — some forks' `install.sh` (observed on NetShift) detect a stale `/etc/config/podkop` and print an interactive `(yes/no)` migration confirmation. Invoked headless from the bot (no attached terminal), the prompt's `read` gets EOF, is treated as "no", and the installer exits 1 — not an actual install failure, just an unanswerable prompt. `do_update_podkop` now feeds an endless `yes` stream into the installer's stdin (portable loop, no dependency on the external `yes` applet) — applies to all variants' update path, since the user already opted into "update" by tapping the button.

## v0.15.9
- **NEW: pre-flight overlay disk-space guard (`_pkg_disk_check()`)** — before running podkop/podkop-plus package updates, checks free space on `/overlay` (falls back to `/`) against a 50 MB threshold. podkop-plus's own installer only requires 15 MB, but sing-box's real-world footprint is closer to 50 MB (more for `-extended` builds with extra protocols/Tailscale) — on tight-flash devices (e.g. AX3000T, ~60 MB overlay) the upstream check passes and opkg/apk can run out of space mid-install, leaving neither a working old nor new sing-box binary. Bot now blocks the update with a clear warning instead of letting it fail destructively.
- **NEW: bot self-update notice in Daily/Weekly Report + Check Bot Update (`_bot_update_note()`, `_ver_is_newer()`)** — fetches `version.txt`/`highlights.txt` from GitHub main and, if a genuinely newer version is published, shows a one-line update banner in report headers. Uses proper major.minor.patch comparison (`_ver_is_newer()`) rather than string inequality — guards against the common case where the working copy's `BOT_VERSION` is already ahead of what's published (bumped locally before push), which previously caused false "update available" notices pointing at an older version. Same fix applied to the `Check Bot Update` button.
- **NEW: persistent weekly traffic accumulator (`_traffic_accum_tick()`, `traffic_accum`, `sb_restart_log`)** — Weekly Report traffic delta previously compared a single before/after Clash API snapshot; since `downloadTotal`/`uploadTotal` reset on every sing-box restart (watchdog action, reload, self-update, migration, anything), any restart during the week caused the report to misdiagnose the reset as "first week ever" and show "н/д" instead of real numbers — on a router with weeks of uptime and an active watchdog this happened almost every week. Fixed with a tick-by-tick accumulator: `_traffic_accum_tick()` runs on every `health_interval` cycle inside `start_health_daemon()`'s watchdog loop, banking traffic into `${BOT_DIR}/traffic_accum` and detecting restarts via the same signal (current Clash counter < last-seen counter) that used to be misread as "first run." Restarts are logged with timestamps to `${BOT_DIR}/sb_restart_log` (8-day rotation, same convention as `switch_log`), so Weekly Report now counts real restarts over the actual 7-day window instead of a `logread`-today-only approximation. `WEEKLY_TRAFFIC_BASE` now stores a banked-counter snapshot instead of raw Clash totals.
- **FIXED: stale "sing-box restarts (сегодня)" label in Weekly Report** — text said "today" while the underlying count had already moved to a 7-day window; label corrected to "(неделя)".
- **FIXED: stale header version comment** — script header comment (line 3) was hardcoded to an older version string, out of sync with `BOT_VERSION`.

## v0.15.8
- **NEW: NetShift — full add/delete editor for `selector_text`/`urltest_text` (`_handle_text_links()`, `_text_links_field()`, `get_text_proxy_links()`)** — these UCI options are multiline scalars (not UCI lists), one proxy link per line, used by NetShift's selector/urltest `proxy_config_type`. Previously read-only in the bot; now supports add (validates protocol prefix, rejects duplicates/empty input, appends a line) and delete (line-rejoin, same discipline already used for `proxy_string` url-mode editing), paginated list view (8 per page).

## v0.15.7
- **FIXED (blocker): `local` in main loop in document handler** — `local _doc_file_id` and all other `local` declarations inside the Upload Bot Script document handler were placed in the main event loop (outside any function). In BusyBox ash `local: not in a function` causes immediate shell exit with code 2. Result: every incoming update (including `🏠 Menu` button) hit this handler, bot crashed, procd respawned — infinite restart loop. Fixed: all `local` removed, plain variable assignments used instead.
- **FIXED: `/cancel` and `🏠 Menu` now exit any STATE_INPUT state** — universal intercept added at the top of the STATE_INPUT block in `handle_command`. Any state (`wait_bot_script_file`, `wait_quiet_hours`, `wait_dr_time`, etc.) is now cleanly exited via `/cancel` or Menu without requiring state-specific handling.
- **FIXED: `send_to_all_admins` duplicate message to primary admin** — comparison was `[ "$_aid" = "$CHAT_ID" ]` but primary admin is `$ADMIN_ID`. If both variables differed, primary admin got two copies of every broadcast. Fixed to `$ADMIN_ID`.
- **FIXED: `grep -v '^\$'` typo in admin_ids filtering** — backslash before `$` made the filter match literal `$` instead of empty lines, causing stale entries in broadcast loops. Fixed to `grep -v '^$'` (two occurrences: `send_to_all_admins` and `send_health_alert`).
- **FIXED: temp file cleanup after adding IP sources 4 and 5** — `rm -f /tmp/podkop_ip[123].*` glob did not cover `f4`/`f5` temp files added for `ipify.org` and `2ip.me`. Changed to `podkop_ip[1-5].*` in both `find` and `rm -f` cleanup paths.
- **FIXED: Bot Control Plane card duplicate route chain** — `tr_hint` for `auto` mode showed `Auto: Podkop SOCKS5 → Fallback SOCKS → Custom → Direct → Emergency IPs` in italic, while `Fallback Chain` block below showed the same chain with real addresses. Removed `tr_hint` for `auto` (chain is already in Route Chain block). For `socks`/`direct` modes a short `⚠️` warning is kept. Renamed `Fallback Chain` → `Route Chain`. `tr_hint` is now conditional — only printed when non-empty.
- **NEW: Upload Bot Script** — `📤 Upload Bot Script` button in Maintenance. Sends bot into `wait_bot_script_file` state, then accepts a `.sh` file sent as a Telegram document. Validates shebang, `BOT_VERSION` presence, and syntax (`busybox ash -n` + `sh -n`). Checks init.d for freshness. On success: backs up current binary to `.bak`, installs new file, restarts. Designed for testing patches without GitHub publish and for routers behind ISP blocks where direct GitHub access fails.
- **NEW: Quiet Hours** — watchdog alerts suppressed during configurable time range. Supports overnight ranges (23:00–07:00). `_is_quiet_hours()` helper used in both `send_health_alert` and `_send_alert`. Daily Report is not suppressed. UCI: `quiet_hours_enabled=0`, `quiet_hours_from=23:00`, `quiet_hours_to=07:00`. Bot Settings: `⚫ Quiet Hours: HH:MM–HH:MM | ⏰ Set Range`. Input: `HH:MM-HH:MM` with regex validation.
- **NEW: RAM low-memory watchdog alert** — fires when free RAM < 30 MB, recovery at ≥ 40 MB, re-alerts hourly if persistent. Includes actionable hints (reduce URLTest outbound count, increase `health_interval`, use sing-box stable). Checked every 5 watchdog cycles. Respects `alert_notify` and new `ram_alert` toggle.
- **NEW: `ram_alert` toggle in Bot Settings** — independent toggle to suppress RAM alerts. Default: on. Useful on routers with persistently low RAM (AX3000T + sing-box-extended).
- **NEW: `broadcast_alerts` toggle in Bot Settings** — when enabled, `send_health_alert` (all watchdog alerts) and `_send_alert` (RAM alerts) are sent to all `admin_ids` in addition to primary CHAT_ID. `send_to_all_admins()` helper added. Daily Report always broadcasts regardless of this setting.
- **NEW: IP detection expanded to 5 parallel sources** — added `api.ipify.org` and `api.2ip.me` (Russian, accessible in Crimea/RF where ipinfo.io/ifconfig.me may be blocked). Majority vote updated from 2-of-3 to 2-of-5. All requests parallel, total time = slowest responder.
- **NEW: init.d freshness check during self-update** — before installing new binary, checks `/etc/init.d/podkop_bot` for `_kill_all_podkop_bot` marker (added in v0.15.5). Shows `⚠️ Warning: init.d is outdated` if missing. Non-blocking.


- **NEW: Weekly Report** — scheduled Telegram digest sent once per week (default: Sunday 09:00, off by default). Separate from Daily Report; Daily is suppressed on Weekly Report day. Content: versions block (bot ver + mtime + sha256[:8], init.d mtime, podkop + sing-box versions), stability block (bot uptime, tunnel uptime, sing-box restarts, route switches for the week from `switch_log`, last switch method/time, TG status), resources block (RAM snapshot + weekly min + alert count, resets after report), tunnel (mode + active outbound), traffic delta for the week with avg/day (baseline saved after each report, skipped if Clash API unavailable), Plus subscription with expiry/traffic warnings (<7 days or >80% usage). Bot config snapshot: route, health interval, quiet hours, broadcast alerts, ram alert, daily report. UCI: `weekly_report=0`, `weekly_report_day=7` (ISO: 1=Mon…7=Sun), `weekly_report_time=09:00`. Bot Settings: `⚫ Weekly Report: Sun 09:00 | ⚙️ Set`. Maintenance: `📅 Send Weekly Report Now`. Survives bot restart — last send date persisted to `${BOT_DIR}/weekly_report_last`.
- **NEW: `switch_log`** — watchdog appends `ts|method|from|to` on every proxy switch (manual and urltest). Entries older than 8 days are pruned after each write. Weekly Report reads 7-day count and last entry.
- **NEW: `ram_week` tracking** — watchdog updates `min_free_mb|alert_count|last_ts` on every RAM check. Alert count increments when RAM alert fires. Weekly Report reads and resets this file.
- **NEW: weekly traffic baseline** — `${BOT_DIR}/weekly_traffic_base` stores `ts|download|upload` after each weekly report. Delta = current counters − baseline. Baseline only updated when Clash API returns non-zero counters.

- **FIXED: init.d not updated during bot self-update** — `do_update_bot_` now automatically downloads and installs the latest `podkop_bot_init` from GitHub when the current init.d is detected as outdated (missing `_kill_all_podkop_bot` or `return 0` markers from v0.15.5+). Old backup saved to `/etc/init.d/podkop_bot.bak`. Falls back to a warning message if download fails.
- **NEW: init.d outdated warning in Maintenance card** — shown once per bot session (flag in `${BOT_DIR}/init_warn_shown`) when Maintenance is opened and init.d is detected as old. Previously the warning only appeared during self-update, which users missed if Telegram was unreachable at that moment.

## v0.15.6
- **FIXED (OOM blocker): removed `sing-box version` last-resort fallback** in `get_singbox_version_display()` — spawned full Go runtime (+20-30 MB RSS), could trigger OOM-killer on 256 MB routers. Now falls through to `"unknown"` without binary spawn.
- **FIXED: broken `sed` expression in apk version parser** — `s/ *//)` had unmatched `)`, causing `sed: unknown option to 's'` at runtime. Fixed to `s/[[:space:]].*//'`.

## v0.15.5
- **NEW (Plus only): Server Instances card** — `🖧 Server Instances` button in the main menu (hidden on original/evolution/netshift). Reads all UCI `server` sections from `podkop-plus` config — no dependency on sing-box config.json or Clash API. Displays per-server: protocol (VLESS, VMess, Trojan, Shadowsocks, SOCKS, Hysteria2, MTProto, Tailscale), listen address and port, public host, security mode (Reality/TLS/none) + SNI for VLESS/VMess/Trojan, FakeTLS domain for MTProto, routing mode (rules/direct/section→name). Live port status via `netstat`/`ss`/`/proc/net/tcp|udp` — covers both TCP and UDP (hy2/tuic). Connection stats from Clash `/connections` shown when available (conn count, ↓↑ traffic). Tailscale IP resolved from `tailscale0` interface; falls back to "check LuCI → Server → Share" if tsnet state is unavailable (no system-level tailscaled). MTProto secret not shown in MVP. Status legend: 🟢 port listening · 🟡 enabled in UCI, port not detected · ⚫ disabled.
- **FIXED:** Health daemon potential deadlock — `wait "$_last_probe_pid"` before launching a new `probe_all_socks_write &` could block the entire watchdog loop indefinitely if the previous probe subshell was stuck in D-state (blocked I/O on tmpfs). Fixed: now checks `kill -0` first; if the process is alive, kills it; then calls `wait || true` (non-blocking reap for zombie cleanup). Daemon can no longer hang.
- **FIXED:** `sort_by(.value.all | length)` in `_resolve_urltest_group_for_section` and `_utf_postcheck_warn` — `jq` pipeline crashed with `null` error when a Selector's `.all` array was missing or empty. Fixed: `sort_by((.value.all // []) | length)` — uses empty array fallback.
- **FIXED:** `html_escape` missing in `_flush_autoswitch_summary` — proxy names from subscriptions containing `<`, `>`, or `&` caused Telegram to return 400 Bad Request on URLTest switch alerts, silently losing the notification. Fixed: both `_sw_old_disp` and `_sw_pending_to` are now escaped before insertion.
- **UX:** Tunnel Health — `TG direct: fail` now shows `(expected — ISP block, tunnel OK)` instead of the alarming `(no proxy)` when the direct check fails but the tunnel transport is working. Neutral `(no proxy)` shown only when both direct and tunnel are failing.
- **FIXED (robustness):** `stat -c %Y` replaced with `date -r "$file" +%s` in stale-lock recovery and startup cleanup — `stat -c %Y` requires `CONFIG_FEATURE_STAT_FORMAT` which is not always compiled into BusyBox OpenWrt builds.
- **PERF:** `is_list_enabled` optimized for Community Lists rendering — previously called `uci show` once per tag in the loop (up to 25 subprocess calls, 2-3s on MIPS). Now parses the active list once into `_active_cl_str` and checks membership via `case " $str " in *" $tag "*)` — O(1) per tag, no subprocesses.
- **FIXED:** `killall -9 "$(basename $BOT_PATH)"` in `do_restart_bot` and `do_update_bot` (no-init.d path) killed the current process before `exec` could run — bot died instead of restarting. Fixed: `kill -9 -$$` kills the process group (orphaned subshells) without targeting the main process itself.
- **FIXED:** NetShift/Netshift variants: hardcoded `/etc/sing-box/config.json` replaced with `$SINGBOX_CONFIG_PATH` (set per-variant in the detection block). All 18 occurrences replaced. NetShift subscription cache path fixed from `/etc/netshift/subscriptions/` (flash) to `/var/run/netshift/subscriptions/` (RAM, matching evolution).
- **FIXED:** Log/diagnostic grep commands (`logread`, `nft list ruleset`, Support Bundle) now filter by `"${PODKOP_PKG}|sing-box"` instead of hardcoded `podkop|sing-box` — on NetShift the correct syslog prefix is `netshift`, not `podkop`.
- **FIXED:** `PODKOP_FAKEIP_DOMAIN` variable added to variant detection block. `podkop_dns_check` now uses `${PODKOP_FAKEIP_DOMAIN:-fakeip.podkop.fyi}` — ready for NetShift if its fakeip domain differs.

- **NEW (Plus only): Zapret2 version display in Maintenance** — `Zapret2:` line now appears in the Maintenance card alongside Zapret and ByeDPI when `zapret2_installed=1` is reported by the Plus CLI. Version read from `/opt/zapret2/nfq2/nfqws2 --version` directly (not exposed by `get_system_info`); falls back to `installed` if binary returns nothing.
- **FIXED:** Self-update and manual restart (`do_update_bot_`, `do_restart_bot`) now perform a full `/proc` scan before restarting — kills all surviving `podkop_bot` processes (orphaned subshells from previous restart cycles) except the current PID. Previously only `HEALTH_PID` and own process group were killed; subshells from older cycles that procd's init restart does not clean up survived and caused duplicate Telegram API polling (409 conflicts) and duplicate watchdog alerts.
- **NEW: Daily Report** — optional scheduled message sent once per day at a configurable time (default `08:00`, off by default). Covers: hostname + device model, uptime/RAM/CPU, WAN IP + exit IP + country flag, TG direct/tunnel status, active outbound + latency, nftables rule count, podkop/sing-box versions, traffic ↓↑ + active connections, bot transport tier, and subscription traffic/expiry (Plus only). Enabled and time configured in Bot Settings → `Daily Report` toggle + `⏰ Report time`. Manual send available from Maintenance → `📊 Send Daily Report Now`.
- **IMPROVED: Daily Report** — complete redesign. Now reads from watchdog caches (`SOCKS_STATE_FILE`, `PUBIP_CACHE`, `SOCKS_PROBE_FILE`, `last_switch`) instead of making live network requests. Content: hostname + short device model (stripped of vendor/Router words), uptime + load (single line), RAM, WAN/LAN IPs, external IP + country flag, TG direct/tunnel status (one line), virtual adapters (Tailscale/WireGuard/ZeroTier), section mode (`URLTest`/`Selector`/`Subscription` + section name), active outbound with country flag and human name, last switch time + method (✋ manual / 🤖 urltest), sing-box restart count (fixed: was printing value twice), traffic ↓↑ + connections + sing-box uptime period, bot transport route + reserve channels, Plus subscription block (URL with secrets stripped, traffic/expiry via `get_subscription_metadata` + `_plus_format_sub_meta`). Device model shortened via `sed` to fit mobile screen. `send_daily_report` now protected by `mkdir` lock to prevent double-send on simultaneous scheduled + manual trigger.
- **FIXED (OOM): `get_singbox_version_display` no longer spawns sing-box binary** — previously called `sing-box version` which launches a full Go runtime (+20–30 MB RSS). On 256 MB routers (AX3000T and similar) this triggered OOM-killer, especially in hot paths like Maintenance card. Replaced with a 3-tier pkg-manager read: (1) `/etc/podkop-plus/sing-box-version` state file (podkop-plus writes it after each install — works for out-of-repo binaries like sing-box-extended); (2) `opkg list-installed` (OpenWrt 24.10); (3) `apk list --installed` (OpenWrt 25.x). Binary spawn retained only as last-resort fallback. `SB_VER_CACHE` (`${BOT_DIR}/singbox_version`) caches the result across card opens; invalidated after `do_update_podkop`.
- **FIXED (OOM): Support Bundle** — also called `sing-box version` directly. Replaced with `get_singbox_version_display`.
- **FIXED (OOM): Maintenance card** — duplicate `sb_ver=$(get_singbox_version_display)` call after already-guarded `[ -z "$sb_ver" ]`. Removed the unconditional repeat.
- **FIXED: Daily Report `printf '%b'`** — replaced with direct `send_message "$_text"`. The `%b` flag interprets backslash sequences in user-controlled data (subscription URLs, route strings, hostnames) which could corrupt the message.
- **FIXED: Server Instances newline rendering** — reverted broken `tr '\n' '\n'` (ash-incompatible) back to `printf '%b'`. All user data in Server Instances `_text` goes through `html_escape` before insertion, so `%b` is safe here. The previous "fix" caused the card to render as a single broken line on mobile.
## v0.15.4
- **FIXED:** Installer `cleanup_bot_runtime_files()` did not remove `podkop_bot.pid` (the single-instance lock the bot writes at startup). After an update, the stale lock file survived cleanup — on the next start the bot could see its own stale PID and refuse to launch with "another instance running". Fixed: both `bot.pid` and `podkop_bot.pid` are now included in the cleanup list.
- **FIXED:** Installer `--action status` JSON reported `running: false` when the bot was started directly (not via init.d), because the running check only called `"$INIT_PATH" status`. Now falls back to reading the `podkop_bot.pid` single-instance lock file and verifying the PID is alive — correctly reports `running: true` regardless of how the bot was started.
- **FIXED:** Installer `--action install/update` with unattended mode: when init.d failed to supervise the bot and the direct fallback start was used, the script always exited with code 18 (`service start failed`) — even when the bot process was actually alive and working. Now waits 2 seconds and checks `/proc/$pid` before deciding: exits 0 (with a degraded-mode warning) if the process is running, exits 18 only if it truly died.
- **FIXED:** `podkop_bot_init` (both the repo init script and the locally-generated fallback): `_kill_all_podkop_bot()` cleaned only `podkop_bot.pid` on early-exit, leaving `bot.pid` (used by the installer's `safe_stop_bot`) as a stale file. Now removes both files on stop.
- **FIXED (critical):** Manual proxy link deletion silently failed on Podkop Plus when the section was in URLTest mode. Plus stores all manual links in `selector_proxy_links` regardless of mode — `urltest_proxy_links` is a legacy field Plus itself migrates away from and deletes (`migrate_0_7_17_8_urltest_link` + `podkop_uci_delete_option`, confirmed in Plus binary). The bot's delete handler picked `_del_key` by section mode, targeting `urltest_proxy_links` on Plus URLTest sections — the link visually disappeared from the list but stayed in UCI. Delete now always targets `selector_proxy_links` on Plus, mode-based selection kept for original/evolution/netshift.
- **NEW:** `+ Add` button now shown alongside `✏️ Edit Subscription URL` on Plus subscription sections. Confirmed in Plus LuCI source: `selector_proxy_links` depends only on `action=proxy`, not on subscription presence — manual links and subscription-pulled servers coexist and are tested together by URLTest. Manual-add guard for subscription sections now only applies to non-Plus variants, where subscription remains exclusive.
- **FIXED:** Maintenance card's device model now matches Status card's logic — prioritizes the full string from `/tmp/sysinfo/model`, falling back to Plus CLI `.device_model` only if that file is empty. Previously Maintenance trusted the CLI value first, which is often just a short vendor name rather than the full model string.

- **Installer v2.0.0** — complete rewrite, shipped as part of v0.15.4:
  - **NEW: `--unattended` mode** (`--action install|update|uninstall|status|check`, `--config <json>`). Lock file prevents concurrent runs. Designed as the rpcd backend for luci-app-podkop-bot — no TTY interaction, structured exit codes (0 success, 10 lock, 11 not OpenWrt, 12 missing field, 13 bad JSON, 14 dep install failed, 15 download failed, 16 UCI write failed, 17 token rejected, 18 service start failed), `--action status` outputs machine-readable JSON.
  - **NEW: Podkop variant auto-detection** (original / evolution / netshift / plus) via binary path, UCI field fingerprint (`action=` vs `connection_type=`, Plus-only fields), and package manager metadata. Detected variant is shown in the pre-flight summary and used to pick the correct UCI field names for SOCKS tier1 discovery.
  - **FIXED: `_get_socks_endpoints()` rewritten** to support all 4 variants. Previously only the legacy `connection_type=proxy` schema was checked — on any Plus install tier1 always returned empty, leaving the installer with no SOCKS transport if GitHub was blocked on a first install (no `fallback_socks` exists yet on a clean install).
  - **NEW: Bilingual UI** (English / Russian). Language resolved in order: `--lang` flag → unattended config `"lang"` → interactive prompt → default `en`. All prompts, warnings, and summary text route through `msg()` instead of hardcoded English strings.
  - **NEW: User-supplied bootstrap proxy** for fresh installs where GitHub is unreachable and no podkop SOCKS is available yet. Prompted interactively (skipped in unattended mode); applied temporarily via env vars (`http_proxy`, `https_proxy`, `all_proxy`) for the lifetime of the installer process only — nothing written to UCI or system files. SOCKS proxy rejected before curl is installed (apk/opkg only support HTTP proxy).
  - **NEW: Staged, rollback-safe update** — bot script downloaded to `/tmp/podkop_bot.new`, validated (shebang + `ash -n` syntax check), existing binary backed up, then atomically swapped. If the new version fails to start, the previous binary is restored automatically and the service is restarted.
  - **NEW: `download_file_optional()`** — non-fatal download for the init.d script. Failure no longer kills the installer mid-update (the bot binary is already replaced at that point); falls back to a locally-generated procd init script instead.
  - **NEW: Verbose final summary** — detected podkop variant, podkop/sing-box versions, all file paths, and a "Recommended settings" block explaining why Mixed Proxy matters and how YACD fits in, with exact LuCI paths.
  - **NEW: `_validate_downloaded_script()`** — verifies downloaded shell scripts before trusting them (shebang present + `ash -n` passes), catching HTML error pages or truncated downloads that curl/wget report as success.
  - **FIXED: Unattended uninstall** skips the interactive YES/REMOVE double confirmation — the luci-app caller is expected to have already confirmed in its own UI.
  - **FIXED: Separate trap handlers** for EXIT / INT (130) / TERM (143); `umask 077` + `chmod 600` on the config file so the bot token is never world-readable.
  - **FIXED: `--action status`** quiet mode: `exec 1>/dev/null` before all noisy detection steps, stdout restored to fd 3 only for the final JSON — nothing leaks into the caller's pipeline.

## v0.15.3.fix1
- **FIXED:** Tunnel Health false "TG tunnel: fail" on a working bot — probe A2 computed its own IP/port via raw `network.lan.ipaddr` and used `--socks5-hostname` curl syntax, diverging from the live poll path. Now calls `_load_transport_ctx` directly (resolves actual sing-box listen address from `config.json`) and uses the same `-x socks5h://` syntax as `_try_socks_tiers`.
- **FIXED:** `detect_server_country` (Plus) was treated as a boolean (`toggle_uci_bool`, default `"0"`) but is actually a 3-value mode (`flag_emoji` | `country_is`, default `flag_emoji`) with its own UCI migration. Writing `0`/`1` caused Plus to silently migrate the value back on reload. Replaced with `do_utfilter_cycle_dc` — cycles `disabled → flag_emoji → country_is → disabled`, with `disabled` written via `uci delete` (never `=0`). Callback renamed in all 3 sync points (button, handler, dispatcher whitelist).
- **FIXED:** `download_lists_via_proxy=1` without `download_lists_via_proxy_section` set breaks Plus subscription/list startup (`subscription_bootstrap_download_section_is_ready` returns 1, fatal log). `do_toggle_dl` now blocks enabling the flag on Plus without a section already set, shows a warning instead.
- **FIXED:** TG direct-connectivity probe used 3 hardcoded Telegram DC IPs with a fixed `≥2` threshold. Now uses the bot's existing `TG_EMERGENCY_IPS` (DoH-refreshed dynamic list) with a majority threshold (`_dc_ok*2 >= _dc_total`) that works for any list size. Removed the hardcoded "2/3 DC" label from the Tunnel Health card.
- **UX:** Status card separators now wrapped in `<code>` tags (matching Tunnel Health / Routing & Lists style) — fixes a mobile-client rendering bug where bare `─────` separator lines could double-wrap onto two visual lines on narrow screens.

## v0.15.3 hotfix
- **FIXED (critical):** Outbounds screen never opened — the if/else refactor of the `proxy_menu` keyboard block dropped one closing `]` in both branches (`}]}"` instead of `}]]}"` ). `jq --argjson kb` failed silently, `payload` was empty, card was never sent.
- **NEW:** `_validate_kb()` — guard added before `send_message` and `edit_message`: validates keyboard JSON via `jq -e` before passing to `--argjson`; on invalid JSON logs `[UI] Invalid reply_markup JSON (cmd=...)` and sends the card without buttons instead of silently failing. `bash -n` / `busybox ash -n` do not catch this class of error.

---

## v0.15.3
- **NEW:** Subscription URL replacement — `✏️ Edit Subscription URL` button in `proxy_menu` for subscription sections (replaces `+ Add`, which has no meaning for auto-managed server lists). Two-step flow: send new URL → confirmation card shows old vs new URL → Confirm applies, Cancel returns without changes.
- **NEW:** Plus: replaces all `subscription_urls` list entries via `uci delete` + `uci add_list`; Evolution/NetShift: replaces single `subscription_url` via `uci set`. Supports `URL | User-Agent` format — trim removes only leading/trailing whitespace, internal spaces preserved.
- **NEW:** `cmd_proxy_add` guard for subscription sections — old cached `+ Add` button redirects to `Edit Subscription URL` with an explanation instead of opening the manual outbound form, preventing accidental corruption of subscription-managed sections.
- **NEW:** `section_display_kind()` helper — returns `subscription` when `section_is_subscription()` is true, regardless of `get_section_type()` result. Ensures sections with both `subscription_urls` and `urltest_enabled=1` are labeled as subscription in display contexts.
- **FIXED:** `pending_sub_url_*` state check moved before `rm -f "$STATE_FILE"` — pending URL stored on line 2 of STATE_FILE is no longer lost if the user sends a text message while on the confirmation screen. Confirmation still works correctly after accidental text input.
- **FIXED:** `do_confirm_sub_url_*` validates STATE_FILE header (`pending_sub_url_<sec>`) before reading the URL from line 2 — stale confirmation buttons from a previous session cannot apply a mismatched URL.
- **FIXED:** Subscription URL display in `proxy_menu`, `cmd_edit_sub_url` prompt and confirmation card now runs through `html_escape` — `&` in query strings no longer causes Telegram HTML parse errors.
- **FIXED:** JSON keyboard escaping in `cmd_edit_sub_url` unsupported-variant notice and `pending_sub_url_*` warning — unescaped braces caused `jq --argjson` to receive invalid JSON at runtime (not caught by `sh -n`).
- **UX:** Status card — section dividers (`─────────────────────`) added between System / Podkop / Telegram / Bot blocks; LAN IP line added (`🏠 LAN: <ip>`); footer reduced to `bot vX.Y.Z` only, eliminating duplicate version display.
- **UX:** Routing & Lists card — `Service Lists` renamed to `Community Lists` (matches LuCI label); `Domain List URLs` → `External Domain Lists`; `Subnet List URLs` → `External Subnet Lists`; buttons: `+ Domain List URL` → `+ Add Domain List URL`, `+ Device → Tunnel` → `+ Device to Tunnel`, `Edit Tunnel Devices` → `Tunnel Devices`, `+ Device → Bypass` → `+ Device to Bypass`, `Edit Bypass Devices` → `Bypass Devices`.
- **UX:** Routing & Lists card (Plus only) — `rule_set` and `rule_set_with_subnets` fields now displayed with URL list and entry count. Read-only; edit note directs to `LuCI → Podkop → Conditions`. Hidden on non-Plus variants.

---

## v0.15.2
- **NEW:** NetShift support — podkop-evolution was renamed to NetShift (`/usr/bin/netshift`, UCI namespace `netshift`). `_detect_podkop_variant()` now detects NetShift before falling through to the `podkop` binary check; variant config sets `PODKOP_UCI=netshift`, `PODKOP_BIN=/usr/bin/netshift`, `PODKOP_GITHUB_REPO=yandexru45/netshift`. UCI schema is identical to evolution (`connection_type`, `proxy_config_type`, `subscription_url`); all variant-aware logic reused without changes. Subscription cache path corrected to `/etc/netshift/subscriptions/<sec>.json`.
- **FIXED:** `domain_ip_lists` field not read on Podkop Plus — current LuCI Plus writes external URL lists to `domain_ip_lists` (label «Domain and IP Lists»), not `remote_domain_lists`. Bot only read `remote_domain_lists`, so lists added via LuCI showed as «No lists configured». Fixed: on Plus, bot reads both fields (merged for display) and writes new entries to `domain_ip_lists`. On original/evolution/netshift, `remote_domain_lists` behaviour is unchanged.
- **FIXED:** `-4` flag added to the direct leg of `_curl_via_best_socks` — eliminates AAAA DNS stall on every GitHub fetch before SOCKS fallback. Fixes update check hanging/failing under podkop's DNS redirect.
- **FIXED:** `-4` on direct legs of GitHub health probes (`api.github.com`, `raw.githubusercontent.com`) — "direct" result in Tunnel Health now reflects true TCP reachability, not AAAA timeout.
- **NEW:** `_pkg_net_check` pre-flight — verifies network reachability (IPv4) before running `install.sh` for podkop updates; reports "Package network unreachable" instead of silently hanging opkg/apk.
- **NEW:** Temporary `/etc/resolv.conf` redirect to public IPv4 DNS during podkop install — lets opkg/apk resolve package hosts through musl without AAAA stall; original config restored atomically via trap.
- **FIXED:** Infinite recursion in `cmd_status` route resolution — `cmd_status` and `/status` are now separate case branches; cyclic proxy reference guard added to `_resolve_leaf`.
- **UX:** Status — public IP hidden when unresolved (no `· Unavailable` clutter); RAM label harmonized; device model moved to Runtime Info.
- **UX:** Outbounds list — each button shows `[idx] ▶/● name` with latency for at-a-glance proxy state.
- **NEW:** Plus CLI integration — `_plus_has_cmd()` (detects command via CLI dispatcher grep, not incomplete `show_help`), `_plus_json()`, `_plus_format_sub_meta()` helpers for all Plus-specific calls.
- **NEW:** `get_system_info` integration — versions and update availability (`podkop_latest_version ≠ podkop_version` → "→ X.X.X available") in Status and Maintenance; zapret/byedpi versions shown when installed; fallback to `opkg info` for original/evolution.
- **NEW:** `get_subscription_metadata` — traffic usage and expiry (`📊 3.2/50 GB · exp 15.07`) shown in main menu for Plus subscription sections.
- **NEW:** `get_outbound_link_states` — outbounds filtered by urltest country/regex rules marked `⊘` in proxy list.
- **NEW:** `close_all_connections` button in Runtime Info (Plus only, via `clash_api`).
- **NEW:** Zapret/ByeDPI section menu — status (running, version), enable/disable toggle, strategy edit with `validate_nfqws_strategy_json`/`validate_byedpi_strategy_json` pre-validation. `section_settings` auto-redirects zapret/byedpi sections to their own menu.
- **NEW:** URLTest Filters menu (`🔬 URLTest Filters (country/regex)`) — `urltest_filter_mode`, `detect_server_country`, `urltest_hide_filtered_outbounds`, country lists, outbound lists. Shows actual excluded outbound names (first 3 + count) instead of just a number.
- **NEW:** `_utf_postcheck_warn()` — after applying urltest filters, checks if any servers remain in the URLTest group via Clash `/proxies`; warns if filter wiped all servers. Per-section lookup (not global first selector).
- **FIXED:** All DPI/urltest write handlers (`do_dpi_toggle_*`, `do_utfilter_*`) guarded with `[ "$PODKOP_VARIANT" = "plus" ]` — stale saved buttons on non-Plus cannot accidentally disable sections.
- **NEW:** GitHub Connectivity block in Tunnel Health — probes `api.github.com` and `raw.githubusercontent.com` via direct (WAN, bypasses fakeip) and SOCKS; shows `✅ Xms` / `❌ unreachable` per path.
- **NEW:** Unified Diagnostics entry point — Runtime Info → single `Diagnostics` button; `cmd_diagnostics` hub contains Tunnel Health+GitHub, Probe, Proxy Latency Test, Internal Diag, Support Bundle.
- **NEW:** `_in_tg_range()` — glob-based validation of Telegram CIDR prefixes (AS62041, all 10 prefixes, 95.161.64/20 boundary correct).
- **NEW:** `resolve_tg_emergency_ips()` — parallel DoH query to 1.1.1.1, 8.8.8.8, dns.quad9.net via WAN+`--noproxy`; validates IPs against `_in_tg_range` (anti-poisoning); replaces static `TG_EMERGENCY_IPS` in memory. Refresh every 6h in watchdog + on-demand at tier5 entry.
- **FIXED:** SOCKS inbound type detection expanded to `mixed|socks|socks5` in `_load_transport_ctx` and `get_proxy_ip`.
- **NEW:** Device model in Status and Maintenance — reads `device_model` from `get_system_info` (Plus), falls back to `/tmp/sysinfo/model`; `"unknown"` from Plus treated as empty to allow fallback.
- **NEW:** Reply keyboard — persistent `🏠 Menu | 📊 Status` bottom keyboard; installed once per session via `install_reply_keyboard_once`; nav escape in state machine (clears STATE_FILE, exits to Menu/Status); `/status` as slash command.
- **NEW:** Section switch confirmation — `set_sec_X` shows "Switch to X? Podkop will reload" before acting; `do_set_sec_X` executes.
- **FIXED:** Watchdog — "Telegram reachable" alert reads `MAIN_ROUTE_FILE` instead of `LAST_ROUTE_NAME` (which is "Initializing…" in subshell); empty/Initializing → "via SOCKS (recovered)".
- **FIXED:** Watchdog — auto-switch alert: icon `🔀`, compact single-line format `🔀 old → new (urltest)`; debounce 120s window batches rapid flapping into `🔀 Proxy switched ×N in Xm`.
- **FIXED:** Watchdog — `_recovery_ts` suppresses duplicate "Telegram reachable" alert within 30s of "Primary SOCKS recovered".
- **FIXED:** `cmd_get_config` uses `/etc/config/${PODKOP_UCI}` — was hardcoded `/etc/config/podkop`, broke Config & Logs on Plus.
- **UX:** Subscription URL shown in Outbounds menu for subscription sections (first 3 URLs, truncated to 60 chars).
- **UX:** URLTest Filters dispatch fixed — `urltest_filters_menu` and `do_utfilter_*` routed to `_handle_section_extras` (was incorrectly `_handle_settings`, causing silent no-op).
- **UX:** Protocol validator updated to match Plus parser: `ss, vmess, vless, trojan, hy2, hysteria2, socks, socks4, socks4a, socks5`; `tuic` removed (not supported by Plus parser).
- **UX:** Routing & Lists screen renamed — `FR IP → Device → Tunnel (➡️)`, `Excl IP → Device → Bypass (↩️)`, `R-Domain → Domain List URL`, `R-Subnet → Subnet List URL`, `Custom Domains/Subnets → My Domains/Subnets`, `Community Lists → Service Lists`; legend added: "What goes through the tunnel — and what bypasses it."
- **FIXED:** `section_is_subscription` and `get_section_type` use `uci show` instead of `uci get` for `subscription_urls` list field — BusyBox ash `uci -q get` returns empty for list fields.
- **FIXED:** `get_subscription_urls` uses `sed` parsing of `uci show` output; display built with `awk` to avoid ash subshell variable scope issue with `while+pipe`.

---

## v0.15.1

- **NEW:** `section_settings` and `global_settings` — `advanced_settings` split into per-section and global screens; `advanced_settings` kept as redirect for back-compat.
- **NEW:** `cmd_maintenance` screen — versions, Check Update, Restart Bot, GitHub releases link per variant.
- **NEW:** `cmd_info` redirects to `cmd_status`.
- **NEW:** DNS moved to Global Settings; removed from Section Settings.
- **NEW:** `log_level` removed from bot UI → notice "Use LuCI or SSH".
- **NEW:** YACD secret/WAN management removed from bot → notice; only enable/disable toggle remains.
- **NEW:** Status refactor — aggregate severity header (`✅ running` / `⚠️ limited` / `🟡 fallback` / `❌ action required`); human-readable Connectivity block; Bot route block with tier labels; footer with versions.
- **NEW:** `_status_severity()` and `format_age()` helpers.
- **FIXED:** `do_switch_mode_*`, `do_set_conn_*`, `do_toggle_mixed` return to `section_settings` (not `global_settings`).
- **FIXED:** `wait_outbound_iface` returns to `global_settings`; `wait_vpn_iface` to `section_settings`.
- **FIXED:** Dispatch: `section_settings/global_settings` → `_handle_settings`; `cmd_maintenance` → `_handle_bot`; `dns_settings` → `_handle_dns` (were all incorrectly merged into one case).

---

## v0.15.0 - NEW FEATURES FOR PODKOP FORKS SUPPORT - PODKOP PLUS and EVOLUTION

- **NEW:** `_detect_podkop_variant()` — auto-detects original/evolution/plus; sets `PODKOP_VARIANT`, `PODKOP_UCI`, `PODKOP_BIN`, `PODKOP_INIT`, `PODKOP_PKG`, `PODKOP_GITHUB_REPO`, `PODKOP_DISPLAY_NAME`.
- **NEW:** `set_section_action()` — writes `action` (Plus) or `connection_type` (original/evolution); maps `exclusion→direct` for Plus.
- **NEW:** `get_section_type()`, `_get_wan_interface()`, `section_is_subscription()`, `_variant_has_subscription()`, `get_subscription_cache_path()`.
- **FIXED:** False `direct ✅` check via `--interface WAN --noproxy '*'` to bypass fakeip routing.
- **FIXED:** Plus urltest flag — reads/writes `urltest_enabled` instead of `proxy_config_type=urltest`.
- **FIXED:** Proxy link writes always go to `selector_proxy_links` on Plus (`urltest_proxy_links`/`proxy_string` are migration-only fields wiped by Plus on load).
- **FIXED:** `user_domain_list_type=text` and `user_subnet_list_type=text` set when writing `*_text` list fields (both variants — fields ignored when list_type≠text).
- **FIXED:** `conn_type_menu` shows `Direct` instead of `Exclusion` on Plus; `do_switch_mode_url/outbound` blocked on Plus with notice.

## v0.14.4

- **FIXED:** `opkg` on some firmware builds returns version strings with a `v`-prefix (e.g. `v0.7.14-r1`). The pipeline stripped the `-r1` suffix via `cut -d'-' -f1` but left the `v`, producing `v0.7.14`. Arithmetic comparison of `v0` vs `0` triggered `sh: Illegal number`, `_upd` stayed 0, and the bot always reported "Up to date" regardless of actual version. Fixed by inserting `sed 's/^v//'` into both the `opkg` and `apk` pipelines. The same strip was already applied in `cmd_check_update` (introduced in v0.14.2) but was missing from the four other `p_ver` read sites: `_handle_status` (Status screen), `cmd_info` (Info screen), `cmd_diag` (Diagnostics export), and the startup notification. All five sites are now consistent.
- **FIXED:** `cmd_check_update` called `_curl_socks_fallover` — a name that does not exist. The only curl wrapper is `_curl_via_best_socks` (introduced in v0.14.3). The call returned empty output immediately, `latest` was always empty, and the handler bailed with "❌ Cannot reach GitHub" before making any network request. **Root cause:** the task description for v0.14.4 contained the typo `_curl_socks_fallover` instead of `_curl_via_best_socks`; the code was written verbatim from that description. Fixed by correcting the function name to `_curl_via_best_socks`, consistent with `cmd_check_update_bot` and the self-update download (lines 6508, 6516, 6581).
- **FIXED:** `do_update_podkop` — three compounding issues caused the process to hang forever on "Downloading update..." with no feedback: (1) `wget` was used directly instead of `_curl_via_best_socks`, so download silently failed when `raw.githubusercontent.com` is blocked; (2) `install.sh` was launched in background (`&`) — the bot never waited for it and never reported outcome; (3) the log at `/tmp/podkop_update.log` was written but never read or sent. Rewritten: download via `_curl_via_best_socks` with explicit failure message, `install.sh` runs synchronously, on completion the last 20 lines of log are sent with exit status; on success the new installed version is shown.

## v0.14.3

- **NEW:** Runtime Info — added `⏱ Session: Xh Xm` line between traffic and proxy blocks. Shows current sing-box session uptime as context for Downloaded/Uploaded figures. Source: `RELOAD_TS_FILE`, fallback to `/proc/PID/stat`. No extra curl calls.
- **UX:** Bot Settings — `👤 Admins` button moved from its own row to the bottom row next to `🏠 Menu`. Removes the visual gap between functional buttons (Fallback SOCKS, Custom Proxy, Notify) and navigation.
- **NEW:** GitHub fetch fallover via SOCKS — version check and self-update now use `_curl_via_best_socks`: tries direct first, then tier1 (Podkop SOCKS), then each tier2_N fallback in order. Prevents "Cannot reach GitHub" errors when raw.githubusercontent.com is blocked by ISP. Route is shown in the result card when a proxy was used (direct = silent).
---

## v0.14.2

- **FIXED:** `outbound_interface` — бот читал и писал `podkop.${sec}.outbound_interface` (поле в секции), которое podkop 0.7.x не читает. Реальные поля: `podkop.settings.output_network_interface` (глобальное, единое для всех секций) и `podkop.settings.enable_output_network_interface`. Исправлено во всех 5 местах. При сохранении интерфейса теперь также выставляется `enable_output_network_interface=1`, при сбросе — `=0`. Карточка и подсказка помечены `(global)`.
- **FIXED:** `connection_type=vpn` без заданного `interface` — podkop завершался с fatal abort «VPN interface is not set» при reload. Добавлен гард в `do_set_conn_vpn`: если `podkop.${sec}.interface` не задан, бот сохраняет тип в UCI, ставит `wait_vpn_iface` и **держит reload** до получения имени интерфейса. Симметрично защите для `url` режима. Кнопка «Cancel — revert to Proxy» откатывает без reload.
- **FIXED:** Defense-in-depth для переключения режимов прокси — `do_switch_mode_urltest` и `do_switch_mode_selector` теперь повторно проверяют наличие ссылок в соответствующем UCI-списке **на стадии выполнения**, а не только на стадии подтверждения. Если список пуст — возвращает «Refused» с контекстными кнопками, reload не выполняется, podkop не падает. Ранее пользователь мог проигнорировать предупреждение на ask-этапе и вызвать fatal abort в podkop.
- **FIXED:** Сравнение версий podkop при проверке обновлений (`cmd_check_update`) — GitHub-теги вида `0.7.14-r1` не очищались от суффикса `-r1`, что делало `_l3 = "14-r1"` нечисловым и ломало `[ "14-r1" -gt "10" ]` с ошибкой «Illegal number». Бот всегда показывал «Up to date» даже при устаревшей версии. Исправлено добавлением `| cut -d'-' -f1` в pipeline для `latest`.
- **FIXED:** После клонирования URLTest→Selector (`cmd_clone_utl_to_sel`) при `_added=0` и `_skipped>0` сообщение «Cloned 0 links» заменено на явное «Selector Proxy Links already up to date — all N links already exist».
- **FIXED:** `do_switch_mode_` — перед `safe_reload_podkop` теперь явно удаляет все три кэша (`TAG_NAME_CACHE`, `UCI_LINKS_CACHE`, `TAG_URI_CACHE`). Устраняет отображение устаревших имён прокси после смены режима.

---

## v0.14.1

- **FIXED (Critical):** `eval "set -- $(uci_list_clean \"$var\")"` — all 33 occurrences replaced with 2-step `{ _ucl=$(uci_list_clean "$var"); eval "set -- $_ucl"; }`. The inline `$(...)` form caused `sh: eval: Syntax error: Unterminated quoted string` in ash whenever a UCI list contained single-quoted values (which all `*_proxy_links` lists do). The eval failure crashed the **entire subshell** silently (exit code 2), causing: (1) `build_tag_name_cache` producing 0-entry cache → empty proxy names in Outbounds, alerts, startup notification; (2) `send_startup_notification_async` subshell dying before ever sending the startup message; (3) all proxy add/delete/count operations silently failing in URLTest mode.
- **FIXED:** Startup ordering — `ACTIVE_SECTION_FILE` is now initialized **before** launching `send_startup_notification_async &` and `start_health_daemon`. Previously caches were built for `main` (fallback default) even when the user's primary section had a different name.
- **FIXED:** Self-update infinite loop — after the `BOT_DIR` path change, `OFFSET_FILE` moved from `/tmp/podkop_bot_offset` to `/tmp/podkop_bot/offset`. On first start after update the new path didn't exist, offset reset to 0, and Telegram replayed the pending `do_update_bot_` callback — triggering another download and restart endlessly. Fixed with two guards: (1) startup migration copies old offset to new path if new path is missing; (2) `do_update_bot_` handler skips re-install if downloaded version equals `BOT_VERSION` — **unless** the callback came from the Force Update button (which uses `do_update_bot_force_VERSION` to bypass the guard). Force Update always re-applies regardless of version match.
- **REFACTORED:** All 27 persistent bot runtime files consolidated under `BOT_DIR="/tmp/podkop_bot"` (created with `mkdir -p`). Trap simplified to `rm -rf "$BOT_DIR"`. Eliminates `/tmp` clutter and makes cleanup atomic.

---

## v0.14.0

- **FIXED:** `_load_transport_ctx` — tier1 (bot transport to Telegram) now always uses the **primary proxy section** (`connection_type=proxy` + `mixed_proxy_enabled=1`), not the active UI section. Previously switching active section to e.g. `awg_main` (WARP/VPN) caused bot to use port 2081 for its own transport, breaking connectivity.
- **NEW:** `_load_transport_ctx` auto-adds other sections' `mixed_proxy` endpoints as additional fallback tiers. Each section with `mixed_proxy_enabled=1` and a different port is appended to `_t_fb_socks` after explicit `fallback_socks` entries — no manual configuration needed.
- **FIXED:** `check_health` A2 now uses primary proxy section for tier1 health check (same fix as transport ctx).
- **NEW:** `check_health` A3 tests **each section's mixed_proxy independently** — per-section results written as `tg_sec_<name>=ok|fail` to `HEALTH_STATE_FILE`. Aggregate `tg_tier2` is ok if any section passes.
- **NEW:** Tunnel Health — **"Active outbounds by section"** block: read-only overview of active proxy and delay for every podkop section simultaneously. No section switching needed — see all paths at a glance. Sections without Selector/URLTest group (VPN type) show N/A gracefully.
- **NEW:** Tunnel Health — per-section TG reachability lines (`✅ TG via awg_main: ok`) from per-section health check results.

- **FIXED:** `do_toggle_mixed` — enabling mixed proxy when `mixed_proxy_port` is not set in UCI caused podkop to pass empty string to `--argjson listen_port` in `sing_box_config_manager.sh`, producing `jq: invalid JSON` and aborting sing-box config generation. Bot now auto-assigns port before enabling: scans all sections for used ports, starts from 2080 and increments until a free port is found. Confirmation screen shows the port that will be auto-assigned.
- **FIXED:** `do_toggle_mixed` — if `podkop reload` fails after toggle, user now sees explicit error message with `logread` hint instead of bot silently returning to settings screen.
- **FIXED:** `build_uci_links_cache` always read `selector_proxy_links` regardless of mode — in URLTest mode the cache was always empty (0 entries), causing proxy deletion to fail with "Cannot resolve link". Now reads `urltest_proxy_links` when `proxy_config_type=urltest`.
- **FIXED:** Root cause confirmed from podkop 0.7.14 source: `configure_section_mixed_proxy()` calls `config_get mixed_proxy_port "$section" "mixed_proxy_port"` with no default — only `mixed_proxy_port` is affected, all other `--argjson` calls in podkop use `_normalize_arg()` or hardcoded values.

---
## v0.13.99

- **FIXED:** TG direct check now uses `--resolve` to bypass DNS and connect directly to Telegram DC IPs (149.154.167.220, 149.154.167.51, 91.108.56.190) — requires 2/3 DCs to respond. Previously resolved through DNS which could return CDN/Cloudflare IPs giving false positive under RKN blocking.
- **NEW:** `check_health` A3: probes first fallback SOCKS (tier2_1) against Telegram API — result shown as tier2 ✅/❌ in Status and Tunnel Health. Hidden when no fallback configured.
- **UX:** Status and Tunnel Health — merged `tunnel` and `SOCKS` into single `tunnel SOCKS5` indicator. Green = transport ok + SOCKS up, yellow = transport ok but SOCKS port down, red = transport fail.
- **NEW:** `mixed_proxy` disabled guard in Probe — shows clear error instead of N/A results when mixed_proxy is off.
- **NEW:** Clash API availability check in Probe — shows "Enable YACD" hint if Clash API unreachable.
- **NEW:** Active section initialized from first configured podkop section at startup (not hardcoded `main`).
- **FIXED:** Public IP display shows `N/A` instead of `?` when IP unavailable (double NAT / unreachable).
- **NEW:** `Test Fallback` button added to Bot Settings top level alongside Fallback SOCKS entry.
- **NEW:** Podkop Settings — `Test Proxies` button added to top-level settings menu.
- **UX:** All Menu navigation buttons now show 🏠 — disambiguates "go back one screen" (← Back) from "go to main menu" (🏠 Menu).

---

## v0.13.98

- **FIXED:** `get_active_proxy_name()` restored to return Clash API tag/leaf only — previously returned human display name in url mode which broke tag comparisons throughout the UI (active proxy marking in Outbounds list, Probe button visibility in proxy card). Added separate `get_active_proxy_display()` helper for display-only contexts.
- **FIXED:** Single URL Proxy menu — status showed 🔴 Offline when delay is 0 (untested). Changed to 🟡 Untested — delay is 0 when sing-box hasn't pinged yet, not when proxy is down.
- **FIXED:** Single URL Proxy menu — delete button showed ping icon and delay instead of trash icon. Restored `${E_DEL} [N] host` format; status is already visible in the header line.
- **FIXED:** Probe Active Outbound navigation from Single URL menu — Cancel and Back returned to Diagnostics instead of url_links_menu. Added `ask_probe_outbound_url` callback with `url_links_menu` back target.
- **FIXED:** Probe result action button in url mode — showed "Switch Proxy" (proxy_menu) which is wrong for Single URL. Now shows "Set New URL" (cmd_url_link_add) when throttled/blocked.
- **FIXED:** Active proxy display in Status, Runtime Info, Tunnel Health, Probe — now uses `get_active_proxy_display()` which shows human name from `#fragment` in url mode.
- **NEW:** Probe result back button label adapts to context: "Diagnostics" / "Single URL" / "← Back".
- **FIXED:** Cache race condition — `build_all_caches` no longer called before `safe_reload_podkop` in add/delete proxy paths. Cache was built on stale `config.json` producing empty `TAG_URI/UCI_LINKS/TAG_NAME` caches, causing raw `main-N-out` tags instead of human names in Outbounds.
- **FIXED:** `safe_reload_podkop` waits up to 10s for `config.json` validity (`.outbounds | length > 0`) before building caches. Skips cache build with warning if timeout exceeded.
- **FIXED:** Cold-start cache race — `send_startup_notification_async` now waits up to 10s for `config.json` validity before `build_all_caches`. Skips with warning on timeout; lazy getters handle first-access rebuild.
- **FIXED:** `get_uri_by_tag`, `get_selector_link_by_index` — check `-s` (non-empty) instead of `-f`; rebuild on miss with retry.
- **FIXED:** `display_proxy_name` — on `TAG_NAME_CACHE` miss, ensures `TAG_URI_CACHE` is fresh before rebuild (dependency chain: name cache depends on URI cache for server:port matching).
- **FIXED:** Tunnel Health and startup notification now use `get_active_proxy_display()` for consistent human name in url mode.

---


## v0.13.97

- **CRITICAL FIX:** Add proxy (`wait_proxy_link`) always wrote to `selector_proxy_links` regardless of active mode. In URLTest or Selector mode the new proxy went into the wrong UCI list — podkop read both lists when generating sing-box config, produced an invalid JSON, and aborted with `[fatal] Sing-box configuration is invalid`. Tunnel went down, all proxies appeared lost from the bot UI. Fix: detect `proxy_config_type` at add time and write to `urltest_proxy_links` (urltest mode) or `selector_proxy_links` (selector mode) accordingly.
- **FIXED:** Single URL Proxy menu — Back button returned to `advanced_settings` instead of `proxy_menu`. Now returns to Outbounds as expected.
- **NEW:** Single URL Proxy menu — shows active proxy name, ping delay and verdict (Excellent/Good/Acceptable/High latency), consistent with Selector and URLTest menus.
- **NEW:** Single URL Proxy menu — Probe Active Outbound button added when proxy is active.
- **FIXED:** Proxy Card (px_view) — Share Link was truncated at `#` stripping the proxy name fragment (e.g. `#medved`). Now shows full link including fragment.

---

## v0.13.96

- **NEW:** probe_geo now queries Cloudflare cdn-cgi/trace as second geo source — independent of ipapi.co, no rate limits, plain text parse. Result card shows GeoIP (ipapi.co), Cloudflare, and Google as three separate country indicators.
- **REMOVED:** DNS hijacking check — not reliable with podkop/sing-box architecture (fake-IP, FakeTLS, stubby intercept all DNS including public resolvers, making honest ISP comparison impossible).
- **FIXED:** probe_services — Claude.ai probe moved from status.anthropic.com (always 200, separate infra) to api.anthropic.com/v1/models. Returns 401 (auth required) = service reachable, 403/timeout = geo-blocked or unreachable. Note: claude.ai/login returns 403 for all datacenter IPs via Cloudflare bot protection regardless of geo — api endpoint gives honest signal.
- **NEW:** Gemini added to probe_services — gemini.google.com/app with browser UA.
- **NEW:** version.txt now includes highlights line (line 2) — bot update card shows concise summary without fetching CHANGELOG.

---

## v0.13.95

- **NEW:** Probe Active Outbound — two-stage throughput test. Stage 1: 32 KB fast check detects 16 KB block pattern (РКН drops connection after first ~16 KB). Stage 2: 1 MB accurate speed measurement (skipped if Stage 1 shows block). Result shows MB/KB automatically based on actual downloaded size.
- **NEW:** Probe Active Outbound — Gemini added to service checks. `gemini.google.com/app` with browser UA and `-L` follow; geo-blocked regions get 403 or redirect.
- **FIXED:** Claude.ai probe now tests `claude.ai/login` (real Cloudflare-protected endpoint) instead of `status.anthropic.com`. Status page is hosted on separate infra and always returns 200 regardless of geo/proxy ban — previous check was a false positive.
- **FIXED:** DNS hijacking probe: `nslookup` now queries ISP upstream DNS explicitly (not local resolver). Reads `/tmp/resolv.conf.auto` first (WAN DHCP DNS), then `/etc/resolv.conf`, skipping loopback/private ranges. Eliminates false positives from stubby, FakeTLS, local dnsmasq.
- **FIXED:** DNS hijacking probe: added `198.18.*` and `198.19.*` (podkop fake-IP, RFC 2544) to local address filter. Without this, any blocked domain resolved via sing-box fake-IP would trigger false hijacking alert.
- **FIXED:** DNS hijacking probe: DoH fallback via proxy when ISP blocks direct DoH. If direct `cloudflare-dns.com`/`dns.google` unreachable — retries through active SOCKS. Result distinguishes: hijacked / ok / ok (ISP blocks direct DoH) / inconclusive.
- **NEW:** Bot update check shows What's New from CHANGELOG.md. Fetches remote CHANGELOG, extracts bullet points for new version via `awk`, shows up to 8 items with full changelog link. Gracefully falls back to version-only display if CHANGELOG unreachable.
- **FIXED:** `uci_list_clean` — replaced `echo` with `printf '%s
'` to prevent BusyBox interpreting `-n`/`-e` prefixed values as flags.
- **FIXED:** `probe_throughput` raw field parsing hardened against partial curl output on RST/timeout — each field sanitized with `grep -oE` numeric pattern, defaults to 0.

---

## v0.13.94

- **NEW:** Probe Active Outbound — new Diagnostics feature. Tests the currently active proxy through `mixed_proxy` SOCKS without switching selector or interrupting traffic. Four sequential checks: (1) Geo — exit IP, country, ASN via ipapi.co; (2) Google hint — parses `MgUcDb` field from google.com, shows how Google sees the exit country; (3) Service reachability — YouTube, Telegram API, ChatGPT, Discord through the proxy, each with HTTP status classification (OK / Redirect / Blocked / Timeout); (4) Throughput — 200 KB Range download via speed.cloudflare.com with ISP throttle and 16 KB block detection. Result card shows all findings in one message with context-aware action buttons.
- **NEW:** RKN throttle/block detection in throughput probe. Three classified states: `ok` (≥0.8 Mbps), `throttled` (<0.8 Mbps but data flows), `block16k` (received ~14–20 KB then connection dropped — known RKN pattern of cutting traffic after first 16 KB), `blocked` (no data received). Each state shows appropriate warning text explaining the pattern.
- **NEW:** Telegram API reachability check through active outbound. Detects when a proxy (especially Russian VDS) passes general traffic but blocks `api.telegram.org` — explains why the proxy cannot be used as bot fallback tier2. If blocked, result card shows Bot Settings button to remove it from fallback list.
- **NEW:** Context-aware action buttons on probe result. If throttled/blocked in Selector mode → "Switch Proxy" button (opens Outbounds). If throttled in URLTest mode → "Test All Proxies" button (triggers URLTest re-evaluation). If Telegram API blocked → "Bot Settings" button. No action button when all OK.
- **NEW:** Probe cooldown — 2 minute lockout between runs via `/tmp/podkop_probe_ts` timestamp file, consistent with safe_reload pattern.
- **UX:** Diagnostics menu — "Probe Active Outbound" (🔬) added as first item, above Upstream Health.
- **UX:** Main menu — Section name no longer merges with Active Route line when multiple sections configured. Fixed heredoc trailing-newline stripping by using conditional `printf` instead of variable interpolation.
- **UX:** Startup notification — clock emoji 🕐 removed from latency display in Bot Path line.
- **UX:** Custom Proxy input prompt expanded — now shows all supported formats: `socks5://`, `socks5h://`, `socks5h://hostname:port`, `http://`, `https://`, bare `IP:PORT`. Explains that `socks5h` is recommended (remote DNS). Notes tier3 role in transport chain.
- **UX:** Fallback SOCKS input prompt updated — mentions hostname support, shortened and restructured for clarity.

---

## v0.13.93

- **FIXED:** Outbounds list regression — all proxies showed "Unknown | N/A" and internal group nodes (main-urltest-out) leaked into the list. Root cause: jq pipeline used `.proxies[$sel].all | to_entries[]` which shifts the context away from the JSON root, making subsequent `.proxies[name]` lookups read from the entry object instead of the root. Fixed by adding `. as $root` at the start of both `total` and `page_tsv` jq expressions, then using `$root.proxies[...]` throughout. Affected Selector and URLTest modes; px_view cards were unaffected as they use separate direct queries.
- **FIXED:** do_px_auto_urltest ("Switch to URLTest auto" button) searched for URLTest group globally across all Clash API proxies, picking the first one found anywhere. In multi-section configs this could activate a URLTest group from a different section (e.g. main instead of antiz). Now scoped to `$root.proxies[$sel].all[]` — only searches within the current selector's members.
- **FIXED:** Single URL mode (proxy_config_type=url) appended new URLs to proxy_string instead of replacing. The UI said "This replaces any existing URL" but the code did `printf '%s\n%s' "$existing" "$safe_link"`. Fixed to `uci set proxy_string="$safe_link"` — strict single-link semantics now match the UI.
- **FIXED:** Outbound Config mode SSH hint had hardcoded `podkop.MAIN.outbound_json=...`. Replaced with `podkop.${sec}.outbound_json=...` so the hint reflects the actual active section name.
- **NEW:** podkop_dns_check() function — tests tunnel health after reload via fakeip DNS probe (nslookup fakeip.podkop.fyi 127.0.0.42, expects 198.18.x.x). Borrowed from podkop_autoupdater (VizzleTF). Now used in do_reload_podkop: after reload shows "✅ Tunnel OK" or "⚠️ Tunnel check failed" instead of just "Reloaded!".
- **FIXED:** cmd_check_update version comparison used sort -V which is not guaranteed on BusyBox. Replaced with numeric field-by-field comparison (split x.y.z, compare each part with -gt/-eq).
- **UX:** Status card (cmd_status) — 🐶 emoji for Podkop line, 📦 for Sing-box, 📨 for Telegram health row, 🐧 before OS. Clock emoji 🕐 removed from uptime and bot route latency. WAN and Public IP merged into one line (Public IP shown only when different from WAN). Telegram health reworded from "TG direct / via SOCKS / SOCKS" to "direct / tunnel / SOCKS".

---

## v0.13.92

- **FIXED:** api_poll_long() recovery path did not call _write_main_route() after successful SOCKS rediscovery. MAIN_ROUTE_FILE and MAIN_ROUTE_KEY_FILE remained stale, causing watchdog to read the old tier and potentially fire false "route degraded" nudges.
- **FIXED:** urltest_group detection in _handle_proxy() used a global jq search across all Clash API proxies, picking the first URLTest node found anywhere — could steal data from a different section (e.g. main) when active section was antiz. Now searches only within .proxies[$selector].all[] members scoped to the active section.
- **FIXED:** sed -nE replaced with POSIX BRE sed -n (no -E flag) in extract_server_port_from_uri(). BusyBox sed on some OpenWrt builds supports -r but not -E.
- **FIXED:** do_restart_bot and do_update_bot used killall -9 $basename after init.d restart, risking killing the newly spawned instance. Replaced with kill -9 $$ (own PID) — only the current process is terminated, new instance is safe.
- **NEW:** Check E in watchdog — bot transport route degradation alerts. Fires when bot route drops to tier4 (Direct) or tier5 (Emergency IPs), with a clear message explaining the situation. Recovery alert fires when route returns to tier1/tier2. Separate from SOCKS alerts.
- **NEW:** Tier1 SOCKS down alert even when tier2 keeps bot reachable. Previously if tier2 fallback was alive, curr_socks_state was reset to "up" and no alert fired — user saw nothing while primary SOCKS was down. Now tracks last_tier1_state separately: fires "Primary SOCKS unavailable, switched to fallback" alert, and "Primary SOCKS recovered" when tier1 comes back.
- **FIXED:** Group nodes (URLTest/Selector/Fallback/LoadBalance) were included in the Outbounds proxy list. sing-box internal routing nodes like main-urltest-out appeared as selectable entries with VLESS type. Now filtered out from display and total count; pagination adjusted accordingly; orig_idx preserved for correct px_view_N callbacks.
- **UX:** Status card (cmd_status) redesigned for mobile readability — each item on its own line, no forced line merges. Changes: 🐧 added before OS, 🐶 replaces ⚙️ for Podkop line, 📦 replaces 🔌 for Sing-box, 📨 replaces 🔍 for Telegram health, ✅ for one-shot done status, 🟢 for sing-box RUNNING. RAM shown inline with | separator.
- **UX:** WAN and Public IP merged — Public IP only shown when different from WAN (NAT). Saves one line when ISP gives white IP.
- **UX:** Clock emoji 🕐 removed from uptime and bot route latency — context makes units clear.
- **UX:** Telegram health line reworded from "TG direct / via SOCKS / SOCKS" to "direct / tunnel / SOCKS" — more intuitive for new users.
- **UX:** URLTest outbounds card title changed to "URLTest Outbounds" (was "Outbound Selector"). Mode hint changed from "Manual: fixed" / "Auto: best ping" to "Pinned manually" / "URLTest: auto-selecting". Auto button renamed "URLTest auto ✓" / "Switch to URLTest auto".

- **FIXED:** Refresh toast (answerCallbackQuery) could silently fail on slow routers. CB_ANSWER_TEXT was set before clash_request but answer_callback was only called after handle_command returned — by then Telegram's ~5s callback query timeout could have already expired, causing a "Bad Request: query is too old" error and no toast shown. Fix: proxy_menu Refresh now calls answer_callback immediately (before clash_request), then sets CB_ANSWER_TEXT="__ANSWERED__" to signal the main loop to skip the second answer call. Toast now reliably appears within milliseconds of the button press.

---

## v0.13.90

- **FIXED:** get_selector_tag() used a greedy fallback that could steal data from a different section. When active section was "antiz" in urltest mode, the fallback searched for ANY Selector-type node in the entire Clash API response (ignoring section scope) and picked the largest one — which happened to be from "main". Result: bot showed main section's proxies and route while the user was in "antiz". Three-part fix: (1) added explicit check for $sec+"-out" tag before falling back; (2) fallback now accepts URLTest nodes in addition to Selector (so urltest-mode sections are found); (3) fallback filtered to only nodes whose key starts with the active section name — cross-section data theft is no longer possible.

- **NEW:** Proxy mode switch guard for URL mode — switching to URL mode without a configured proxy_string no longer reloads podkop (which would crash with "[fatal] Proxy string is not set"). Bot saves the mode to UCI, holds the reload, and enters wait_url_link state immediately. User sends the proxy link in chat; bot saves it and then reloads safely. Cancel button reverts to selector mode without any reload.
- **NEW:** URL mode warning on switch screen — if proxy_string is empty, confirmation screen shows a red warning explaining the link must be provided before reload. If proxy_string is already set, screen shows the current URL.
- **NEW:** Check D (leaf change watchdog) now distinguishes manual vs automatic proxy switches. Tracks Clash API .now field (last manual selector choice) alongside the resolved leaf. If .now changed → alert says "Proxy manually switched" (user action via bot or LuCI). If .now unchanged but leaf changed → alert says "Proxy auto-switched" (URLTest picked a faster server). Prevents confusion when bot reports a switch the user just made themselves.
- **FIXED:** get_active_proxy_name() did not resolve URLTest groups — returned raw tag like "main-urltest-out" instead of the actual active proxy. Was checking only Selector type; now uses _resolve_leaf() which iterates through any chain of Selector/URLTest/Fallback/LoadBalance nodes. Fixes "Active Route: main-urltest-out" in main menu.
- **FIXED:** podkop version display showed two versions concatenated (e.g. "v0.7.10-r1 v0.7.14-r1") on RouteRich and similar custom OpenWrt forks where opkg returns multiple Version: lines for podkop. Fixed by adding tail -1 to all 5 version detection sites — takes only the last (newest) entry.
- **FIXED:** proxy_link counter (used for Clone from Selector button) reported wrong count on some OpenWrt versions where uci show outputs all list items on a single line. grep -c counted lines not items. Replaced with eval "set -- $raw"; count=$# which is format-independent.
- **UX:** proxy_menu card title now reflects actual mode: "Outbound Selector" in selector mode, "URLTest Outbounds" in urltest mode.
- **UX:** URL mode renamed throughout for clarity: main menu button "URL Links" → "Single URL"; card title "URL Links" → "Single URL Proxy"; add button "Add Link" → "Set URL"; prompts updated to reflect single-link semantics.
- **UX:** installer option 4 (Uninstall) added — full removal with double confirmation (type "YES" then "REMOVE"). Removes bot binary, init.d script, /etc/config/podkop_bot, all /tmp runtime files. podkop and sing-box are untouched.

- **FIXED:** ROOT CAUSE of "tir1" watchdog false-positive nudge loop — diagnosed via [RouteWrite] + hex dump debug logs added in v0.13.89. Log showed: route_key_raw='tier1' hex= clean=tir1 Root cause: BusyBox tr on OpenWrt 24.10.x incorrectly treats 'e' (0x65) as a member of the [:space:] character class. Confirmed on Redmi AX6000 (MT7986A, ARM Cortex-A53) running stock OpenWrt 24.10.5 — not platform-specific, likely affects all OpenWrt 24.10.x builds with that BusyBox version. Effect: tr -d '[:space:]' on "tier1" produced "tir1" (dropped 'e'), which did not match the case pattern tier1|tier2_* → watchdog fired IPC nudge every 120s indefinitely, causing continuous RECOVERY_MODE=2 cycles, extra transport resets, and "recover old=unknown" log spam. Fix: replaced ALL tr -d '[:space:]' with tr -d '\n\r\t ' (explicit whitespace chars only). Affects 2 watchdog reads + 5 user input validators + 2 IP fetch cleaners. sed 's/[[:space:]]//g' uses sed's own regex engine (unaffected) and was left unchanged.
- **REMOVED:** [RouteWrite] debug logger from _write_main_route (was added in v0.13.89 for diagnosis, now spammed every API call — removed).
- **REMOVED:** [Watchdog] route_key_raw/hex debug logger (same, now resolved).

- **REFACTORED:** All syslog and Telegram alert messages rewritten for readability. Syslog: internal variable dumps (RECOVERY_MODE, FAST/POLL, method=) replaced with human-readable sentences. Cache lines renamed [Core]. Health summary reformatted as single [Health] line. Watchdog IPC messages now describe actions, not internal mechanics. Telegram alerts: sing-box stop/recover, SOCKS down/recover, proxy switch, TG connectivity — all rewritten to focus on user impact, removing technical terms (tier1, control plane, Scope:) in favour of plain English.

---

## v0.13.89

- **FIXED:** Proxy delete (ask_del_px_*) — root cause identified and fixed. get_selector_link_by_index(tag_idx) assumed "main-N-out" tag == UCI list position N-1. This is false: after any add/remove the tag numbering in sing-box config.json diverges from UCI list order. Wrong index → wrong link → uci del_list silently deleted a DIFFERENT proxy or nothing. Tag index step removed entirely. New approach: always match by server:port from TAG_URI_CACHE (order-independent, unique per outbound). Two fallback levels: (1) grep in UCI_LINKS_CACHE, (2) live uci show scan. Covers all protocol types: vless, hy2, trojan, tuic, ss+auth, ss-no-auth (no @ in URI). Error message now returns to px_view_N instead of proxy_menu.
- **FIXED:** extract_server_port_from_uri() failed on ss no-auth format "ss://host:port" (no @ present). Old regex required @ in URI. New regex handles both: with-auth scheme://user@host:port and no-auth scheme://host:port. Affects all server:port matching.
- **FIXED:** test_px_ (Test button in proxy card) replaced the card with a loading message, causing visual jump: card disappears → reappears. Now sends a separate status message below the card, keeps card visible throughout, deletes status message when done.
- **FIXED:** cmd_all_delay_test same jump issue — already fixed in this version, now also preserves current page number in refresh call.
- **FIXED:** Refresh button (proxy_menu_p_N) appeared frozen for ~10s with no feedback. Now shows inline loading indicator immediately by editing the card to "Refreshing..." before the clash_request call. Also: retry logic on empty response + better error message with Retry button.

---

## v0.13.88

- **FIXED:** clash_request() missing --max-time on all curl calls. connect-timeout 3 only covers TCP handshake; if Clash API accepts connection but hangs on response (sing-box under OOM/high load), watchdog Check D blocked the entire health cycle indefinitely. Added --max-time 10 to all 4 curl invocations (GET+auth, GET, PUT+auth, PUT).
- **FIXED:** Watchdog probe zombie accumulation at long uptime (30d+). probe_all_socks_write runs as background & every PROBE_EVERY cycles (~every 5 min). In BusyBox ash, background subshells stay as zombies until parent calls wait(). Over a month: ~8640 zombies × (3 curl + 1 ash subshell). Fixed: track _last_probe_pid, call wait "$_last_probe_pid" before launching the next probe.
- **FIXED:** refresh_public_ip_cache() temp file leaks under RAM pressure. (a) mktemp for f1/f2/f3 was unchecked — if any failed, lockdir leaked and curl subshells forked into /dev/null. Now each mktemp is checked with explicit rollback (rm previous + rm lockdir). (b) Final mktemp for atomic write also unchecked — same lockdir leak. (c) mv "$tmp" "$PUBIP_CACHE" could fail (full tmpfs) leaving $tmp orphaned. Now: mv || { rm -f "$tmp"; ... }.
- **FIXED:** probe_all_socks_write() unchecked mv — temp file leaked if tmpfs full. Now: mv || rm -f "$_probe_tmp".
- **FIXED:** tier4/tier5 reprobe compound condition bug. Pattern `_try_socks_tiers || { [...] && _try_curl && ROUTE_KEY=tier3 && ... }` is ambiguous in some BusyBox ash versions: the && chain inside {...} after || can fail to assign ROUTE_KEY/ROUTE_NAME before the outer if tests the result. Replaced with explicit if/elif/else + `[ -n "$ROUTE_KEY" ]` guard — unambiguous in all POSIX ash implementations.
- **FIXED:** trap missing glob cleanup for orphaned temp files. Added: /tmp/podkop_updates.* /tmp/podkop_req.* /tmp/podkop_clash.* /tmp/podkop_ip[123].* /tmp/podkop_pubip.* These files are created mid-cycle and not cleaned if bot receives SIGKILL (which bypasses trap).
- **NEW:**   Startup stale temp file cleanup: find+stat sweep of /tmp for all podkop_* temp file patterns older than 60s. Runs once after singleton guard. Removes orphans from previous SIGKILL'd runs without racing against a legitimate concurrent process.

---

## v0.13.87

- **UX:**    Core Settings keyboard redesigned — 2-column layout grouped by theme: Row 1: Conn type + Proxy mode         (core routing behaviour) Row 2: Mixed Proxy toggle + Port       (same entity, same row) Row 3: Outbound iface + DNS            (network routing config) Row 4: URLTest + Domain Resolver       (per-section extras) Row 5: YACD + Autostart               (system-level) Row 6: Disable QUIC + Update interval  (global flags) Row 7: DL via Proxy + Excl. NTP        (global flags) Row 8: Bad WAN toggle + Bad WAN Details (same entity, same row) Row 9: Log level + Back Card body trimmed: separators instead of verbose multi-line hints, all state visible at a glance in one compact block. outbound_iface now read into local var at top of handler (was a mid-keyboard inline local — inconsistent with other vars).

---

## v0.13.86

- **FIXED:** Nudge case uses negative match (tier1|tier2_* = good, everything else = nudge). Previously explicit list (tier4|tier5|fail|unknown) missed stale/typo values like 'tir4' left on disk from old bot versions after killall -9 (no trap). Both baseline nudge and per-cycle nudge updated.
- **FIXED:** installer safe_stop_bot now calls cleanup_bot_runtime_files() which removes all /tmp/podkop_bot_* IPC/state files before deploying new binary. Prevents stale route keys, nudge timestamps, socks state from old versions affecting the new bot's startup behavior.

---

## v0.13.85

- **FIXED:** tier4 sticky now reprobe SOCKS tiers every 30s (mirrors tier5 mechanism). Previously bot stuck on Direct indefinitely when Telegram accessible directly (TG direct: ok) — sticky tier4 never failed so full discovery never ran. Now shares SOCKS_REPROBE_TS_FILE with tier5 for unified reprobe cadence.
- **FIXED:** Nudge throttled to 120s (was every ~30s watchdog cycle). Continuous nudge caused IPC "up" to reset LAST_ROUTE_FAST=unknown on every cycle, triggering full discovery → recover old=fail new=tier4 loop. Bot could never stabilize.
- **FIXED:** Per-cycle nudge now uses curr_socks_state (current cycle) instead of last_socks_state (previous cycle). Nudge now fires on same cycle tier2 is confirmed alive instead of one cycle later.
- **FIXED:** Watchdog baseline sends IPC "up" immediately if SOCKS is up but bot route is degraded (tier4/tier5/unknown) on first cycle. Previously baseline set last_socks_state=up → no down→up transition ever fired → no IPC up from RECOVERED handler → bot stuck on Direct indefinitely after cold start.
- **FIXED:** Check C (SOCKS probe) now also probes all fallback_socks (tier2_N) when tier1 is down. If any tier2 alive → curr_socks_state=up → nudge fires → bot rediscovers tier2 instead of staying on Direct.
- **FIXED:** api_request_fast no longer zeros RECOVERY_MODE on success — decrements instead. Zeroing caused next api_poll_long to skip SOCKS-first path and land on Direct if tier1 was slow to respond post-recovery.
- **FIXED:** IPC "up" sets RECOVERY_MODE=2 (was 0). RECOVERY_MODE=0 caused _try_all_tiers to miss tier1 on tight connect-timeout and fall through to Direct. With =2, next 2 poll cycles probe SOCKS aggressively.
- **FIXED:** Pre-initialize MAIN_ROUTE_KEY_FILE="unknown" and MAIN_ROUTE_FILE= "Initializing..." at startup before watchdog fork. Without this watchdog read empty file → sent nudge → IPC up reset FAST/POLL → bot landed on Direct before tier1 confirmed reachable.
- **FIXED:** Self-update and do_restart_bot: added killall -9 podkop_bot after init.d restart (sync ubus call) to clean up zombie watchdog subshells. init.d restart is now synchronous (no &) so procd queues restart before killall fires.
- **FIXED:** cmd_status health_st now reads SOCKS_STATE_FILE with icons instead of raw HEALTH_STATE_FILE keys (was showing "tg_direct=ok tg_transport=ok").
- **FIXED:** Bot Settings cp_hint blank line — empty cp_hint no longer leaves blank line between Custom Proxy and Bind Interface (${cp_hint:+ ${cp_hint}}).
- **NEW:**   Restart Bot button in Info (ask_restart_bot / do_restart_bot).
- **NEW:**   Restart Router button in Info with double confirmation: step 1: button press (ask_restart_router_1) step 2: type YES in chat (wait_restart_router_confirm state) Any other input cancels with echo of what was typed.
- **UX:**    Menu button added to all remaining deep screens: cmd_status, cmd_runtime, cmd_tunnel_health, fallback_socks_menu, urltest_settings, domain_resolver_settings, badwan_details, cmd_runtime Back row.
- **UX:**    installer: update flow now shows full summary (version, path, useful commands) instead of bare "Done." line followed by exit 0.
- **UX:**    installer: vv0.7.14-r1 → v0.7.14-r1 (opkg returns version with leading v, installer added another one via "v${PODKOP_VER}").

---

## v0.13.80

- **FIXED:** Watchdog summary log showed "route=Initializing..." permanently because LAST_ROUTE_NAME is a fork-time copy of the parent variable (always stays "Initializing..." in the watchdog subshell). Now reads from MAIN_ROUTE_FILE which is written by the main process on every successful tier resolution.
- **COSMETIC:** Removed duplicate singleton guard comment ("by scriptname" line left over from v0.13.78 rename, sat above the correct "by BOT_PATH pattern" comment). No behavior change.

---

## v0.13.79

- **UX:**    Bot Settings card redesigned into 4 visual blocks with separators: [1] Transport Policy + Active Route + TG Latency [2] Fallback Chain (active tier bold ◀ active) [3] Overrides: Custom Proxy + cp_hint + Bind Interface [4] Uptime + Started / Last Command / Unauthorized Attempts Keyboard restructured into 3 semantic rows: Row 1: Transport | Health Interval Row 2: Fallback SOCKS Row 3: Custom Proxy | Bind Iface Row 4: Startup Notify | Alert Notify Row 5: Menu st/al icons pre-computed into variables (no inline $() in kb string).
- **UX:**    cmd_files (Configs & Logs) now has Menu button alongside Back.
- FIX:   Singleton guard comment updated: "by scriptname" → "by BOT_PATH pattern".

---

## v0.13.78

- **FIXED:** Broken reply_markup JSON in Diagnostics (cmd_diagnostics, ask_upstream_health, ask_run_podkop_tests, ask_run_internal_diag, ask_support_bundle) and Bot self-update (cmd_check_update_bot, ask_update_bot_*, do_update_bot_* error branches). Unescaped {"inline_keyboard":...} as literal shell arg caused Telegram to reject all requests silently (no keyboard rendered). Fixed by using kb="{\"inline_keyboard\":...}" variable pattern throughout.
- **FIXED:** Self-update wget without timeout replaced with curl --connect-timeout 5 --max-time 8/15. wget -qO- on OpenWrt hangs indefinitely without -T flag.
- **FIXED:** Singleton guard: pgrep -f "podkop_bot" → pgrep -f "$BOT_PATH" to avoid matching unrelated processes. Less greedy, more precise.
- **UX:**    Menu button added to all Diagnostics screens (hub + 4 ask_* confirms) and Bot self-update screens (check, ask, error branches).
- **UX:**    cp_hint spacing: explicit newline between cp_hint and Bind Interface line prevents visual merge when hint is non-empty.

---

## v0.13.77

- **FIXED:** Source of truth for route key in watchdog — architectural cleanup. Root cause: MAIN_ROUTE_FILE holds human-readable names ("Podkop (SOCKS5:...)"), not tier keys. grep -oE 'tier[0-9_]+' on it always returned empty. SOCKS_STATE_FILE.route= was written by watchdog from stale subshell LAST_ROUTE. Both fallbacks in per-cycle nudge therefore read wrong/stale data.

  Fix: new MAIN_ROUTE_KEY_FILE (/tmp/podkop_bot_main_route_key) written by main process at every successful tier resolution via _write_main_route() helper. _write_main_route(key, name) atomically updates both KEY and NAME files. All tier resolution points updated: tier1..tier5 sticky + full discovery + tier5 reprobe + api_request_fast recovery path.

  Per-cycle nudge now reads MAIN_ROUTE_KEY_FILE directly — no grep heuristics, no stale var, no fallback chain needed.

  _write_socks_state() drops route= and route_name= fields (were stale subshell copies). SOCKS_STATE_FILE now contains: tg, tg_direct, tg_transport, socks, last_ok only. Tunnel Health and rt_socks_state reads unaffected (use socks= key).

  MAIN_ROUTE_KEY_FILE added to trap cleanup.

---

## v0.13.76

- **FIXED:** BOT_PATH not declared — self-update mv/exec expanded to empty string. Added: BOT_PATH=$(readlink -f "$0" || echo "/usr/bin/podkop_bot") near BOT_VERSION. readlink -f resolves symlinks at runtime, fallback matches installer default path.
- **FIXED:** Per-cycle watchdog nudge read stale LAST_ROUTE from subshell scope (fork-time copy, never updated). Now reads from MAIN_ROUTE_FILE (written by main process on every successful tier resolution) with fallback to route= key in SOCKS_STATE_FILE. Both are file-based IPC, same pattern as ROUTE_CMD_FILE already used for watchdog→main comms.
- **FIXED:** html_escape() missing double-quote escaping. URLs in remote_domain/ subnet list <a href="..."> cards could contain " and break HTML parse mode → Telegram 400. Added: -e 's/"/\&quot;/g'
- **UX:**    Tunnel Health "TG via SOCKS" renamed to "TG via Podkop (tier1)" with note "(primary mixed_proxy — not full bot transport chain)". Prevents confusion: this metric only probes tier1, not tier2_N/tier3.

---

## v0.13.75

- **FIXED:** Transport tier return logic — bot now reliably comes back to tier1 after podkop/sing-box recovers. Three-part fix: 1. IPC "up" now also clears SOCKS_REPROBE_TS_FILE → tier5 reprobe fires immediately on next _route_request, not after 30s timer. 2. Per-cycle watchdog nudge: every health cycle, if socks=up AND sing-box running AND bot route=tier4/tier5/fail, sends IPC "up" to main loop. Replaces the previous PROBE_EVERY-only nudge (was up to ~5 min lag). 3. Removed duplicate IPC "up" from PROBE_EVERY block (now per-cycle).
- **UX:**    Scope line added to all 7 watchdog alert types: TG reachable/unreachable: "Scope: bot control plane" sing-box STOPPED: "Scope: data plane DOWN + bot transport resetting" sing-box RECOVERED: "Scope: data plane restored — bot returning to tier1" Bot SOCKS DOWN: "Scope: bot control plane — podkop data routing unaffected" Bot SOCKS RECOVERED: "Scope: bot control plane — returning to tier1" Proxy switched: "Scope: outbound selection only — no service interruption" Consistent one-line clarifier: operator sees immediately what broke and whether user traffic is affected.

---

## v0.13.74

- **FIXED:** TG health semantics in Tunnel Health — split into two independent metrics. check_health() now probes TWO paths and writes TWO keys to HEALTH_STATE_FILE: tg_direct=ok|fail    — raw curl, no proxy (expected fail under RKN) tg_transport=ok|fail — curl via primary mixed_proxy SOCKS (Podkop tier1) Returns 0 (success) if either path works. _write_socks_state() reads both keys from HEALTH_STATE_FILE and forwards them to SOCKS_STATE_FILE (keeps tg= for backward compat). Watchdog: updated grep to use [ tg_direct=ok ] || [ tg_transport=ok ] instead of pattern matching on "Connected|via SOCKS" string.
- **UX:**    Tunnel Health now shows two TG lines: "TG direct: ok|fail (no proxy)" "TG via SOCKS: ok|fail (Podkop tier1)" Under RKN: direct=fail, SOCKS=ok — both visible, no false alarm. "fail" on TG direct no longer triggers confusion because label is honest.

---

## v0.13.73

- **UX:**    Runtime Info split: heavy tests moved to new Diagnostics screen. Runtime Info now shows: connections, traffic, active proxy, selector, type/delay, bot route summary. Keyboard: Tunnel Health | Diagnostics | Configs & Logs | Refresh | Back. No heavy actions on this screen.
- **NEW:**   cmd_diagnostics — dedicated hub for all active test operations: Upstream Health, Global Check, Internal Diagnostics, Support Bundle. Intro text explains these are active tests that may take 10-30 sec.
- **NEW:**   ask_* confirm screens before every heavy action: ask_upstream_health, ask_run_podkop_tests, ask_run_internal_diag, ask_support_bundle. Each shows what the action does, estimated time, and Run / Cancel buttons. Consistent with existing ask_*/do_* pattern.
- **UX:**    Back navigation from all heavy actions now returns to cmd_diagnostics instead of cmd_runtime (upstream_health, global_check, internal_diag, support_bundle).
- **FIXED:** html_escape applied to human_name in Outbound Selector list text. URI fragment user-names with <>&  could break Telegram HTML parse mode.
- **FIXED:** html_escape applied to _fb, cp, bi, m_ip in Bot Settings tr_chain. After removing <code> wrapper these values render as raw HTML.

---

## v0.13.72

- **NEW:**   Bot self-update from Telegram menu (cmd_check_update_bot). Info screen now has two update buttons: podkop and bot separately. cmd_check_update_bot: fetches version.txt from GitHub, compares with BOT_VERSION, shows diff or "up to date" with force-update option. ask_update_bot_<ver>: confirm screen before applying. do_update_bot_<ver>: downloads to /tmp/podkop_bot_update.PID, validates shebang + BOT_VERSION present, atomic mv to BOT_PATH, kills HEALTH_PID (watchdog), then init.d restart or exec fallback. Sends confirmation message BEFORE restart (last message before down).
- **FIXED:** Installer: safe_stop_bot() added — kills main PID from pid file AND runs killall -9 podkop_bot before replacing binary during update. Prevents zombie watchdog subshells that survived procd SIGKILL.

---

## v0.13.71

- **FIXED:** ZeroTier/Tailscale interface line in Status merged with CPU Load line. $() subshell strips trailing newlines from awk output, so extra_ifs lost its trailing \n. Now explicitly appended when extra_ifs non-empty.
- **FIXED:** Tunnel Health "TG reach: fail" misleading when bot works via SOCKS. check_health() now tries direct curl first, then SOCKS fallback. HEALTH_STATE_FILE writes "Connected", "via SOCKS", or "Disconnected". Watchdog grep updated to match both "Connected" and "via SOCKS". Tunnel Health label renamed "TG direct" with "(fail under RKN is normal)" hint so users understand the distinction between direct and SOCKS reach.

---

## v0.13.70

- **FIXED:** routing_excluded_ips wrote to per-section UCI (podkop.<sec>.routing_excluded_ips) but podkop reads it from podkop.settings.routing_excluded_ips (global setting). All 5 references corrected. Card header now shows [global] with note.
- **FIXED:** url_proxy_links UCI key does not exist in podkop. proxy_config_type=url uses proxy_string (multiline textarea, one URL per line). get_url_proxy_links() rewritten to read proxy_string. _handle_url_links add/delete fully rewritten: add appends line to proxy_string, delete rebuilds proxy_string without target line, empty = uci delete.
- **NEW:**   proxy_mode_menu — full 4-mode selector (url/selector/urltest/outbound). Previously Mode button only toggled selector<->urltest. Now opens a menu with all modes; active mode shown with checkmark. ask_switch_mode_ expanded with correct warning text for each mode. proxy_mode_menu added to dispatch routing.
- **UX:**    Active proxy in Outbound Selector list: bold name + E_PLAY icon. Inactive proxies show latency icon only (no active_mark clutter).
- **UX:**    Bot Settings Fallback Route chain: active tier highlighted in bold with "◀ active" marker. Removed <code> wrapper so HTML renders. Active tier determined from LAST_ROUTE_FAST variable.

---

## v0.13.69

- **FIXED:** ZeroTier interfaces (zt<hex>, e.g. zt3jnfoa3b) were not shown in Status — pattern matched "zero" but ZeroTier uses "zt" prefix. Added "zt" to the interface filter regex.
- **UX:**    Extra VPN interfaces now show human-readable labels: Tailscale, ZeroTier, AmneziaWG, WireGuard, VPN (tun*) Format: "🌐 Tailscale (tailscale0): 100.x.x.x"

---

## v0.13.68

- **FIXED:** Alert flood — root cause was two bot instances running simultaneously. procd sends SIGTERM then SIGKILL, but watchdog subshell can survive. New singleton guard at startup: reads BOT_PID_FILE, kills stale instance + its subshells, writes own PID. Prevents duplicate watchdog processes each sending independent leaf-change alerts.
- **FIXED:** "Bot route: Initializing..." persisted because MAIN_ROUTE_FILE was only written on tier resolution, but watchdog starts in parallel and fires Check D before main loop resolves first route. Fix: write MAIN_ROUTE_FILE immediately after first successful api_request_fast at startup, before watchdog is forked.

---

## v0.13.67

- **FIXED:** Proxy names with flag emojis showed as raw xNN bytes. BusyBox printf does not support xNN escapes in %b. url_decode() rewritten to use awk (hex->octal conversion) + printf octal escapes, which works correctly on all OpenWrt variants for multi-byte UTF-8.
- **FIXED:** "Bot route: Initializing..." in Proxy switched alerts. Watchdog is a subshell and cannot see parent LAST_ROUTE_NAME updates. New MAIN_ROUTE_FILE (/tmp/podkop_bot_main_route): main process writes current route name there on every successful tier resolution (all sticky + full discovery paths). Check D reads from this file.
- **FIXED:** Proxy switched alert spam during URLTest failover (every few secs). Added 60s debounce: leaf-change alert fires at most once per minute. Rapid consecutive switches (e.g. URLTest probing dead servers) are logged but only the first triggers an alert per 60s window.

---

## v0.13.66

- **FIXED:** "Proxy switched" alert showed "From: main-urltest-out" (URLTest group tag) instead of the actual leaf proxy. Root cause: at watchdog startup URLTest .now is empty, so _resolve_leaf returned the group itself as last_leaf baseline. Fix: after _resolve_leaf, check the resolved node's type — if it's still a group (Selector/URLTest/ Fallback/LoadBalance), discard it and keep last_leaf unchanged. Only fully-resolved leaf proxies are stored as last_leaf.
- **FIXED:** "Bot route: Initializing..." in Proxy switched alert. Watchdog runs as a subshell and cannot see LAST_ROUTE_NAME from the parent process. Fix: _write_socks_state() now writes route_name= to SOCKS_STATE_FILE. Check D reads it via grep before sending the alert.

---

## v0.13.65

- **NEW:**   Bot Control Plane card now shows "Active Route" — the tier currently used by the bot to reach Telegram. Placed between Transport Policy and Fallback Route list so the operator immediately sees whether the bot is on tier1 (Podkop SOCKS5), tier2_N (Fallback SOCKS), tier4 (Direct), tier5 (Emergency IP) or still Initializing. No extra API calls needed — reads LAST_ROUTE_NAME which is always current.

---

## v0.13.64

- **FIXED:** Podkop version showed "Unknown" on OpenWrt 25.x (apk). All 5 version detection sites now try opkg first, fall back to apk. apk package name format: "podkop-0.7.x" -> strips "podkop-" prefix.
- **FIXED:** Main menu button showed "URL Test" in urltest mode instead of "Outbounds". Now consistent: selector/urltest both show "Outbounds".
- **FIXED:** Alert "Tunnel upstream DOWN/RECOVERED" was misleading — implied the VPN tunnel for router traffic was affected. Renamed to "Bot SOCKS upstream DOWN/RECOVERED" to clarify this is the bot's own transport path to Telegram, not the podkop/sing-box tunnel.

---

## v0.13.63

- **NEW:**   URLTest mode: Auto (best ping) button in Outbound Selector. Selector .now pointing at URLTest group = auto mode (sing-box picks fastest). Selector .now pointing at a leaf proxy = manual/fixed. Card header shows "| Auto: best ping" or "| Manual: fixed" hint. Auto button: grayed with checkmark when already auto, active button when manual is fixed — one tap returns to URLTest auto selection. Handler do_px_auto_urltest: PUT /proxies/selector with URLTest group name, detected via .proxies[*].type == "URLTest".
- **FIXED:** display_proxy_name now checks TAG_NAME_CACHE (built from all UCI link lists including urltest_proxy_links) before server:port fallback. URLTest outbound names now show #fragment human names (DE Senko -11d) instead of raw sing-box tags (main-4-out).

---

## v0.13.62

- **FIXED:** URLTest outbound names showed raw sing-box tags (main-4-out, main-urltest-out) instead of human names from #fragment in URI. Root cause: TAG_URI_CACHE (from sing-box config.json) has no
         #fragment; UCI_LINKS_CACHE only included selector_proxy_links. Fix: new TAG_NAME_CACHE (/tmp/podkop_tag_name_cache.txt) built from ALL UCI link lists (selector + urltest + url). Matches tag by server:port from TAG_URI_CACHE, stores tag=Human Name. display_proxy_name() now checks TAG_NAME_CACHE as step 2, before falling back to [type] server:port or raw tag.
- **FIXED:** build_all_caches() now includes build_tag_name_cache(). Section switch, link add/delete all trigger full cache rebuild. Lazy-init in get_selector_link_by_index unchanged (UCI only).

---

## v0.13.61

- **FIXED:** /start and text commands after clearing chat history returned no response. send_or_edit with user's message_id tried to edit user message (impossible) → silent fail. Plain text now passes empty mid so send_or_edit always sends a new bot message. Also fixes second admin /start in a fresh private chat.
- **FIXED:** Bot could stay on tier5 (Emergency IP) indefinitely even after fallback_socks recovered. tier5 sticky never probed SOCKS tiers while tier5 itself worked. Now: every 30s, tier5 sticky path tries _try_socks_tiers first. On success: switches back immediately. Timestamp tracked in SOCKS_REPROBE_TS_FILE (atomic, no watchdog dep).
- **FIXED:** Watchdog now sends IPC "up" every PROBE_EVERY cycles (default 5min) when LAST_ROUTE is tier4/tier5. Forces route reset so next request runs full discovery. Complements tier5 reprobe for tier4 case.

---

## v0.13.60

- **FIXED:** api_request_fast (button presses, sendMessage, editMessage) did not respect RECOVERY_MODE. After podkop stop, FAST route stuck on tier5 sticky and never probed tier2_N even when fallback SOCKS recovered. RECOVERY_MODE was only checked in api_poll_long (getUpdates). Fix: api_request_fast now probes SOCKS tiers first when RECOVERY_MODE>0, same as api_poll_long. On success: sets LAST_ROUTE_FAST, clears RECOVERY_MODE. This ensures button presses resume via fallback SOCKS as soon as a tier2_N becomes available after tunnel restart. NOTE:    In the test log, tier2_1 (192.168.2.238:18088) was genuinely down for ~2 minutes after podkop stop (xray was restarting). The bot correctly used Emergency IP during that window. Once tier2_1 recovered, the bot will now switch back via this fix.

---

## v0.13.59

- **UX:**    Renamed "Proxy Selector" to "Outbounds" / "Outbound Selector" throughout UI. Aligns with sing-box native terminology. Callback names (proxy_menu, cmd_proxy_add etc.) unchanged — only user-visible labels updated. No state/UCI changes. Affected: main menu button, card title, add prompts, URLTest screen. Display of proxy names (from #fragment in URI) unchanged — already works for all protocols (vless/hy2/ss/trojan/vmess/tuic).

---

## v0.13.58

- **FIXED:** Check A comment said "via full fallback cascade" but check_health() uses direct curl, not bot transport stack. Corrected to "direct reachability" — no behavior change, semantic fix only.
- **NEW:**   Proxy switched alert adds Mode (proxy_config_type) and Bot route. e.g. "Section: main | Mode: urltest / Bot route: Podkop (SOCKS5:...)"
- **NEW:**   sing-box RECOVERED now symmetric with STOPPED: PID, Section, Proxy (last known leaf), Bot route at recovery time.

---

## v0.13.57

- **FIXED:** SOCKS alert had double clash_request call (nested get_selector_tag inside another clash_request). Replaced with last_leaf variable already populated by Check D — zero extra curl calls.
- **FIXED:** Check D (leaf tracking) runs every cycle using a single clash_request to localhost:9090 — fast, no TG API calls. Baseline set on first read, no false alarm at startup.

---

## v0.13.56

- **NEW:**   Verbose watchdog alerts — all 3 types enriched with context: SOCKS DOWN/UP: primary endpoint, active proxy, bot route, fallback tier availability from last SOCKS_PROBE_FILE. sing-box STOPPED: section, last active proxy, bot route. sing-box RECOVERED: PID, section. TG unreachable: bot route, SOCKS state. TG reachable: bot route.
- **NEW:**   Proxy leaf change tracking (Check D in watchdog). Per-cycle snapshot of selector.now -> resolved leaf. Alert fires when sing-box auto-switches proxy (URLTest/Selector change). Format: [Host] 🎯 Proxy switched / From: X / To: Y / Section: Z Does not fire at startup — baseline set on first successful read.

---

## v0.13.55

- **FIXED:** do_del_fb debug logging removed (served its purpose in 0.13.54). do_del_fb handler is now clean: find by idx, del_list by value, verify, rebuild if del_list failed. ROOT CAUSE was in 0.13.54: "do_del_*" wildcard in proxy dispatch intercepted do_del_fb_* before it reached _handle_fallback_socks.

---

## v0.13.54

- **FIXED:** ROOT CAUSE of fallback SOCKS delete never working. dispatch pattern "do_del_*" in proxy block matched ALL do_del_ commands including do_del_fb_N, do_del_ul_N, do_del_utl_N. They all silently went to _handle_proxy which has no handler for them and returned without doing anything. Fixed: changed "do_del_*" to "do_del_px_*" — the only actual proxy deletion pattern. do_del_ul_* and do_del_utl_* already have their own dispatch entries further down.

---

## v0.13.53

- **FIXED:** probe_socks_latency and _probe_fast returned 0ms for dead proxies. curl returns time_total even on connection refused (fast fail ~0ms). Now checks HTTP response code: only 204 = alive, else "timeout". Dead proxies now correctly show "timeout" with red icon.
- **FIXED:** probe_socks_latency same issue — watchdog telemetry also showed 0ms as green in Tunnel Health Transport Latency section.
- **DEBUG:** do_del_fb now logs idx, total, value being deleted, and state after deletion to syslog. Also tries del_list by value first, then falls back to full rebuild if del_list failed (verification via grep after commit). This will reveal the root cause.

---

## v0.13.52

- **FIXED:** tier5 (Emergency IP) missing from sticky case in _route_request. After finding tier5, LAST_ROUTE_FAST=tier5 was set but next call found no matching case -> logged "sticky=tier5 miss" and ran full discovery every time. Infinite churn in log. Now tier5 sticky path skips SOCKS tiers and tries direct then emergency IPs directly.
- **FIXED:** sing-box stop did not send IPC down to main loop. Only sent alert. Result: LAST_ROUTE_FAST stayed tier1, sticky probed dead SOCKS every call, then fell to tier5 Emergency IP. Now: watchdog writes "down" to ROUTE_CMD_FILE on sing-box stop (triggers RECOVERY_MODE=4 + route reset). On sing-box recover, writes "up" (triggers route rediscovery). This is the root cause of bot being unresponsive after podkop stop.

---

## v0.13.51

- **FIXED:** Fallback SOCKS delete — after uci rebuild, called fallback_socks_menu with empty mid causing send_message instead of edit. Now passes "$mid" so existing card is updated in-place.
- **FIXED:** Fallback SOCKS add — redundant "Added." toast before menu refresh caused two separate messages. Removed toast, menu refreshes directly.
- **FIXED:** cmd_test_fb_socks used probe_socks_latency (8s timeout per endpoint). With 4 endpoints = up to 32s hang. Replaced with inline _probe_fast() using 3s connect / 5s max per endpoint. Max wait now ~20s for 4 tiers.

---

## v0.13.50

- **FIXED:** Fallback SOCKS delete did not work. uci del_list by value is unreliable on some OpenWrt builds. Now rebuilds the list: uci delete the whole key, then uci add_list for all entries except the deleted index. Reliable on all OpenWrt versions.
- **FIXED:** Duplicate check treated socks5:// and socks5h:// as different endpoints. Now normalizes to host:port before comparison.
- **NEW:**   "Test All" button in Fallback SOCKS menu — probes tier1 (Podkop) and all tier2_N via gstatic 204, shows latency per endpoint. cmd_test_fb_socks handler uses probe_socks_latency().

---

## v0.13.49

- **FIXED:** Proxy list and button format restored to original readable style. List: [idx] icon Name | Type | Delay — same as before. Button: human name only (no "· Type" suffix added in 0.13.48). The · separator was unnecessary and made buttons wider.

---

## v0.13.48

- **FIXED:** TSV update parsing caused field shift when callback_id empty. @tsv uses \t (shell whitespace) so consecutive empty fields collapse: user_id received "false" (is_bot value) -> auth failed. Switched to join("\u001f") + IFS=$(printf '\037') read. U+001F (Unit Separator) is never shell whitespace, empty fields safe.
- **FIXED:** Proxy Selector buttons showed "main-2-outHysteria20" (no separator). Button label now "Name · Type" with middle dot separator.
- **FIXED:** Proxy list showed "[0] 🔴 main-1-out | VLESS | 0 | | N/A" — extra pipe from empty delay. New format: [00] 🔴  N/A   main-1-out Delay left-padded to 5 chars in <code> for vertical column alignment.

---

## v0.13.47

- **FIXED:** ask_cmd_stop had no handler body in _handle_bot — button pressed but no confirmation dialog appeared. Added case with "Stop Podkop?" confirm / cancel screen before do_cmd_stop executes.
- **FIXED:** [Watchdog] SOCKS probe ok logged every cycle (~13s = 270 lines/hr). Now logs only on state change (ok->fail or fail->ok). Per-cycle spam suppressed. SOCKS fail always logged regardless.
- **NEW:**   Summary log every PROBE_EVERY cycles (default 5 min): [Watchdog] status: socks=up sb=running route=Podkop (SOCKS5:...) Replaces ok-spam with periodic health snapshot.

---

## v0.13.46

- **UX:**    Replaced all 17 <code>---...---</code> separators with <code>────────────────────</code> (20x U+2500 box-drawing). Monospace dashes (32 chars) wrapped to 2 lines on mobile; box-drawing at 20 chars fits single line on all screen widths.

---

## v0.13.45

- **NEW:**   Hostname prefix in all watchdog alerts for multi-router supergroup. All 4 alert types now start with [hostname]: [Router] sing-box STOPPED/RECOVERED [Router] ALERT: Bot SOCKS upstream DOWN/RECOVERED [Router] TG Connectivity: ... Hostname read once at watchdog startup from /proc/sys/kernel/hostname. Set per-router via: uci set system.@system[0].hostname=MyRouter

---

## v0.13.44

- **FIXED:** probe_all_socks_write() now includes tier3 (custom_proxy) in latency probe if set. Full transport picture: tier1 + tier2_N + tier3. Tunnel Health section renamed "Transport Latency" to reflect scope.
- **FIXED:** SOCKS_PROBE_FILE write is now atomic: tmp file + mv, same pattern as PUBIP_CACHE. Prevents partial reads by Tunnel Health display.
- **VERIFIED:** No stray trailing ' in printf format strings. All new strings from v0.13.38-43 end correctly with ' \\ (format close + line continuation). ChatGPT review was incorrect on this point.

---

## v0.13.43

- **NEW:**   mixed_proxy_port editor in Core Settings. Button shows current port, text input with 1024-65535 validation, reload on change. With confirmation via separate ask/do flow (port change requires reload — user sees "Applying..." before return).
- **NEW:**   outbound_interface editor in Core Settings. Shows current value (auto if unset), text input for UCI iface name, empty = delete (reset to auto). Reload on change.
- **NEW:**   URLTest Proxy Links editor (urltest_links_menu). Paginated list, add with protocol validation (same as selector_proxy_links), delete with confirmation. Accessible from URLTest Settings screen. Uses get_urltest_proxy_links() helper (eval "set --" pattern, handles = in URLs correctly).
- **NEW:**   get_urltest_proxy_links() — mirrors get_url_proxy_links() for the urltest_proxy_links UCI list key.

---

## v0.13.42

- **NEW:**   probe_socks_latency() — measures round-trip latency through any SOCKS endpoint using single HTTP probe to gstatic 204. Returns "Xms" or "timeout". No side effects on transport state.
- **NEW:**   probe_all_socks_write() — probes tier1 (Podkop SOCKS) and all tier2_N (fallback_socks list) in sequence, writes structured results to SOCKS_PROBE_FILE (/tmp/podkop_bot_socks_probe). Format: ts=<epoch>  tier1=<ms>  tier2_1=<ms> url=<endpoint>  ... Runs in background (&) to avoid blocking watchdog cycle.
- **NEW:**   Watchdog calls probe_all_socks_write every 5 health cycles (default every 5 minutes at 60s interval). Configurable via PROBE_EVERY. First probe runs at cycle 5 (not on startup) to avoid boot load.
- **NEW:**   Tunnel Health screen shows SOCKS Latency section with per-tier results: tier1 + all fallback_socks entries with icons and "probed Xm ago" timestamp. Shows "not yet probed" before first probe cycle.
- **FIXED:** socks5h:// now accepted in Fallback SOCKS validator (v0.13.41).

---

## v0.13.41

- **FIXED:** Fallback SOCKS validator rejected socks5h:// protocol. socks5h:// is critical under RKN: DNS resolves through the proxy tunnel instead of locally (prevents DNS poisoning/blocking). Regex changed from ^socks5:// to ^socks5h?:// to accept both. Error message updated to show both formats and explain the difference.

---

## v0.13.40

- **FIXED:** ask_set_tr_menu / ask_set_tr_* / do_set_tr_* were caught by the generic ask_* catchall in the main router before reaching _handle_bot. Result: pressing "Transport: Auto" showed "Confirm Action set_tr_menu?" instead of the transport selector screen. Fixed by adding explicit dispatch entries before the ask_* fallthrough.
- **FIXED:** delete_message() called with empty string mid caused jq error: "string ("") cannot be parsed as a number". Happened after cmd_upstream_health / cmd_run_podkop_tests which call _handle_bot "cmd_runtime" "" "" "" (empty mid on return path). Added guard: [ -z "$1" ] return 0; numeric check before jq call.
- **UX:**    Bot Settings shows a migration hint when custom_proxy is a socks5:// URL, suggesting to move it to Fallback SOCKS (tier2) for correct failover ordering. The Fallback SOCKS button is directly below.

---

## v0.13.39

- **NEW:**   Support Bundle (cmd_support_bundle) — one button in Runtime Info collects and sends a single .txt file containing: hostname/versions, active section, podkop/sing-box status, full UCI config (bot_token/chat_id redacted), ip route/rule, nft podkop rules, network interfaces, public IP cache, bot transport state (LAST_ROUTE_FAST/POLL/RECOVERY_MODE, SOCKS_STATE_FILE contents), last 80 lines of podkop syslog. Sends via api_document, returns to Runtime Info on completion. Does not duplicate or replace existing individual export buttons (Podkop Config, Sing-box JSON, Syslog, Upstream Health, etc.)

## v0.13.38 — P1 LuCI Coverage

- **NEW:**   Mixed Proxy toggle (mixed_proxy_enabled) in Core Settings. Shows current port, ask/confirm before toggle, reloads on change.
- **NEW:**   URLTest Settings screen (urltest_testing_url, urltest_check_interval, urltest_tolerance) — editable per-section via text input with format validation. Accessible from Core Settings button.
- **NEW:**   Domain Resolver per-section screen (domain_resolver_enabled, domain_resolver_dns_type, domain_resolver_dns_server). Toggle, cycle DNS type (udp/doh/dot), set server via text input.
- **NEW:**   Bad WAN Details screen — expands existing toggle with badwan_monitored_interfaces (space-separated, text input) and badwan_reload_delay (seconds, validated). Toggle button reuses do_toggle_wan so main Core Settings stays in sync.
- **NEW:**   Routing Excluded IPs (routing_excluded_ips) in Routing & Lists. Same UX as Fully Routed IPs: list, add/remove with validation, reload on change. excl_ips_edit / del_excl_* / cmd_add_excl_ip.
- **NEW:**   _handle_section_extras() — new handler for URLTest/DR/BadWAN. STATE_INPUT dispatch covers 6 new wait_ states.

---

## v0.13.37

- **FIXED:** flock FD 200 replaced with FD 9 in uci_commit_safe() and safe_reload_podkop(). FD 200 is non-standard and causes sh -n (dash) parse failure. FD 9 is conventional for advisory locks.
- **FIXED:** cmd_dns_server had unescaped JSON as third arg to send_or_edit. Shell parsed closing " of printf string as end of arg, leaving inline_keyboard JSON unquoted — Telegram rejected with 400. Fixed with proper backslash-escaped JSON and multiline call.
- **FIXED:** Delete buttons in url_links_menu and fallback_socks_menu used literal "X" instead of ${E_DEL}. Now consistent with rest of UI.
- **FIXED:** api_document() did not respect transport policy for fallback_socks and custom_url tiers. In "direct" mode these SOCKS tiers were still attempted. Restructured into policy != "direct" / policy != "socks" blocks matching the semantics of _try_all_tiers().
- **PERF:**  Main loop update parsing: replaced 12 separate jq forks per update with a single jq @tsv call + shell read. On MIPS routers this eliminates ~11 process spawns per button tap (~0.5-1s latency saved). Text field newlines preserved via printf '%b' on @tsv-encoded value.

---

## v0.13.36

- **FIXED:** Transport Policy change (Auto/Socks/Direct) was applied instantly on button tap with no confirmation. Switching to "socks" or "direct" under active RKN blocks could permanently break bot connectivity (bot loses Telegram and can't recover without physical access). Fix:   Three-step confirmation flow: 1. "Transport: Auto" button -> ask_set_tr_menu (mode selector screen) 2. User picks Auto/Socks only/Direct only -> ask_set_tr_<mode> (confirmation screen with mode-specific risk warning) 3. Confirm -> do_set_tr_<mode> (apply + return to Bot Settings) If new mode == current mode, skips confirmation and returns directly. "socks" and "direct" show E_WARN + explicit consequence description. "auto" shows E_OK (safe choice, still requires confirm for symmetry).

---

## v0.13.35

- **FIXED:** Missing local declarations — variables leaked into global scope: * run_upstream_health_report(): added leaf_n to local list. Was assigned in the while-read loop but not scoped, risking pollution across calls. * cmd_status case: added pub_ip_display to local list. Read from cache and used in heredoc text but declared globally. * cmd_runtime case: added active_leaf to local list. Assigned via _resolve_leaf() call but not scoped, could bleed into next handler.

---

## v0.13.34

- **FIXED:** refresh_public_ip_cache() lockfile used $$ which in a background subshell (&) always returns the PARENT process PID, not the subshell. If the subshell died (OOM kill, segfault), kill -0 $lock_pid would succeed forever (parent is alive) — permanent lock until bot restart. Fix:   Replaced file-based lock with atomic mkdir lock. mkdir is a single POSIX syscall with link(2) semantics — either succeeds or fails atomically, no race. Lock is a directory (PUBIP_REFRESH_LOCK now ends in .lockdir) so rm -rf cleans it. Added 5-minute stale-lock timeout: if lockdir mtime > 300s old, it is force-removed and re-acquired (covers crash/OOM scenario without leaking the lock forever). trap updated to use rm -rf for the lockdir on bot exit.

---

## v0.13.33

- **FIXED:** Critical architectural bug — watchdog subshell cannot modify parent process variables. In v0.13.28 watchdog wrote LAST_ROUTE_FAST="unknown" and RECOVERY_MODE=4 directly, but as a subshell ( ... )& it only changed its own copy. Main polling loop never saw the reset. Fix:   IPC via ROUTE_CMD_FILE (/tmp/podkop_bot_route_cmd). Watchdog writes "down" or "up" to the file instead of modifying vars. _route_request() reads the file at the top of every call (both api_request_fast and api_poll_long paths), acts on it immediately, then deletes the file. One file = one atomic signal per event. On "down": LAST_ROUTE_FAST/POLL/LAST_ROUTE="unknown", RECOVERY_MODE=4. On "up":   same reset + RECOVERY_MODE=0 (tier1 rediscovery on next poll).
- **FIXED:** Dead code in cmd_tunnel_health: wd_route and wd_last_ok were parsed from SOCKS_STATE_FILE but never used in the output template. Removed the two grep calls and the variable declarations.
- **NEW:**   ROUTE_CMD_FILE constant + added to trap cleanup.

---

## v0.13.32

- **FIXED:** api_document() declared twice (regression from P1 overhaul merge). Old 4-tier version (lines ~880-941) that wrote to global LAST_ROUTE was silently overwriting the new isolated version (LAST_ROUTE_DOC). Deleted the old duplicate. Only the new version (line ~601) remains.
- **FIXED:** _route_request() tier2_* sticky path: for-loop iterator variable retained last value when break never fired (index out of range). Fixed by using separate _item iterator + _fb="" result variable, only assigned on successful break. Prevents stale fallback_socks endpoint being used after list shrinks below cached tier index. Same fix applied consistently (get_tg_latency already used correct pattern with explicit _fb_url="" reset inside loop body).
- **FIXED:** Stray spaces inside case pattern in handle_command() router: "set_update_int_*|        conn_type_menu" cleaned to proper pipe- delimited pattern without embedded whitespace.

---

## v0.13.31

- **FIXED:** Health alert / menu interleaving. When watchdog sends an alert (sing-box down, SOCKS down, TG connectivity change), the alert message pushed the active menu card up in chat. Next user action edited the buried card — user saw stale menu below the alert. Fix:   send_message() now captures and saves the sent msg_id to LAST_MENU_MSG_FILE. send_health_alert() (new helper wrapping watchdog sendMessage calls) saves the alert msg_id to LAST_ALERT_MSG_FILE. send_or_edit() compares the two: if alert is newer than menu, it deletes the buried menu card and sends a fresh one at the current chat position (below the alert), then clears LAST_ALERT_MSG_FILE so subsequent edits work normally.
- **FIXED:** refresh_public_ip_cache() bare wait replaced with explicit PID wait (p1/p2/p3) — same pattern as cmd_all_delay_test fix.

---

## v0.13.30

- **FIXED:** refresh_public_ip_cache() bare wait replaced with explicit PID wait. Three curl PIDs (p1/p2/p3) now collected before wait, then waited with "wait $p1 $p2 $p3". Prevents hang if function call context ever inherits background processes from outer shell. Mirrors the same fix previously applied to cmd_all_delay_test.
- **VERIFIED:** No local declarations in global while-loop scope (main poll loop starts at line 3831+). Unauthorized-access block and audit block use bare assignments — correct for global scope in POSIX ash.

---

## v0.13.29

- **FIXED:** get_tg_latency() tier2_* now resolves actual fallback SOCKS endpoint by index from UCI list instead of incorrectly using custom_proxy. Previously tier2_N fast-route showed wrong latency or Timeout when bot was actually running on a fallback SOCKS, not custom_proxy.
- **FIXED:** api_document() sticky-path comment removed — function intentionally uses full cascade (no sticky) for multipart uploads. LAST_ROUTE_DOC is set for diagnostics only and does not affect FAST/POLL routing.
- **FIXED:** Bot Settings tr_hint updated to reflect actual tier order: Podkop SOCKS -> Fallback SOCKS (tier2_N) -> Custom -> Direct -> Emergency. Previous hint omitted fallback_socks tiers entirely.

## v0.13.28 — P1 Transport Overhaul

- **NEW:**   api_request_fast() — dedicated fast path for sendMessage/edit/ answerCB/deleteMessage: connect-timeout 2s sticky/3s full, max 8s.
- **NEW:**   api_poll_long() — dedicated poll path for getUpdates: connect- timeout 3s sticky/4s full, max 65s. Never shares state with fast.
- **NEW:**   LAST_ROUTE_FAST / LAST_ROUTE_POLL / LAST_ROUTE_DOC — split route tracking. api_document() no longer poisons fast/poll route state.
- **NEW:**   Tier 2_N: UCI list fallback_socks (podkop_bot.settings.fallback_socks) tried in order between Podkop SOCKS and custom_proxy. Old tiers renumbered: tier3=custom, tier4=direct, tier5=emergency.
- **NEW:**   RECOVERY_MODE counter (0-4): after All transports FAILED, next 4 poll cycles aggressively probe SOCKS tiers before falling to direct.
- **NEW:**   probe_socks_upstream() — 3 probe endpoints (gstatic x2 + cloudflare). Reduces false "SOCKS down" from single-endpoint block.
- **NEW:**   Anti-flap hysteresis 2/2 for both SOCKS and TG alerts: alert fires only after 2 consecutive same-state probes.
- **NEW:**   Structured SOCKS_STATE_FILE (tg/socks/route/last_ok key=value). Tunnel Health screen reads and displays split TG/SOCKS state.
- **NEW:**   Fallback SOCKS manager in Bot Settings: add/view/remove entries (UI: Bot Settings -> Fallback SOCKS button).
- **FIXED:** check_health() uses direct curl, not bot's own transport stack, to avoid interfering with LAST_ROUTE_FAST/POLL during checks.
- **FIXED:** Tunnel Health shows Poll/Fast route keys separately.
- **FIXED:** startup notify uses api_request_fast, logs fast route on connect.

---

## v0.13.27

- **FIXED:** Separator lines wrapped in <code>...</code> tags so Telegram renders them in monospace font - dashes are now uniform width and visually span the full message width alongside bold/emoji content. All 13 heredoc separators + 1 inline printf separator updated.

---

## v0.13.26

- **STYLE:** Separator lines extended to 32 dashes (was 21) to visually span full message width in Telegram proportional font alongside emoji content. Covers all 13 heredoc separators + 1 inline printf separator.

---

## v0.13.25

- **FIXED:** url_proxy_links parsing hardened - replaced heuristic "grep | cut -d= | tr -d '" with get_url_proxy_links() helper using eval "set --" on UCI shell-quoted output. Correctly handles = signs inside URLs (base64 padding in vless/vmess, query params). Affected: url_links_menu list load, ask_del_ul_*, do_del_ul_*, and duplicate check on add.
- **NEW:**   get_url_proxy_links() helper function (mirrors build_uci_links_cache pattern already proven for selector_proxy_links).
- **STYLE:** ASCII separator lines extended from 14 to 21 dashes for better visual separation in Telegram messages.

---

## v0.13.24

- **NEW:**   proxy_config_type=url (URL Connection) full support in bot: view list of links, add new link, remove by index, reload on change. Proxy menu button switches label to "URL Links" in this mode.
- **NEW:**   proxy_config_type=outbound (Outbound Config) shows info screen: warns user to use LuCI/console for JSON editing, links to LuCI.
- **FIXED:** main_menu "Proxy Selector" button is now mode-aware: shows "Proxy Selector" (selector), "URL Test" (urltest), "URL Links" (url), "Outbound" (outbound) so user always sees current mode.
- **FIXED:** Status screen Mode: field shows human-readable label instead of raw UCI value.

---

## v0.13.23

- **FIXED:** Header/CHANGELOG version synced to BOT_VERSION (was stuck at 0.13.21)
- **FIXED:** Tunnel Health keyboard had spurious "Menu" button (duplicate nav); now shows only Refresh + Back, consistent with other detail screens
- **FIXED:** Last reload reads sing-box process start time from /proc/PID/stat when RELOAD_TS_FILE is absent (covers LuCI/console reloads, not just bot)
- **NEW:**   Connection Type selector (proxy/vpn/block/exclusion) in Core Settings
- **NEW:**   Active proxy line added to Tunnel Health from Clash API
- **FIXED:** ASCII hygiene - em-dashes replaced with ASCII hyphens in runtime strings (logger lines, verdict text, bot HTML output)

---

## v0.13.21

- **FIXED:** cmd_all_delay_test hung forever (wait without args caught HEALTH_PID) Now uses explicit per-PID wait loop, max 10 concurrent clash_request
- **FIXED:** build_uci_links_cache reverted to eval "set --" (uci get N broken on BusyBox)
- **FIXED:** remote_domain_lists / remote_subnet_lists display reverted to eval
- **FIXED:** wan_ip removed blocking curl to api.ipify.org in cmd_status (was 4s delay) Replaced with ip route + uci get network.wan.ipaddr (instant)
- **FIXED:** get_tg_latency removed from main_menu (was 3s delay every open)
- **NEW:**   Tunnel Health screen (from Runtime Info) - nftables rules, sing-box RAM, last reload time, section mode, active community lists, WAN iface
- **NEW:**   proxy_config_type switch (selector <-> urltest) with mandatory confirm
- **NEW:**   user_domains_text line editor: view paginated, add line, remove by index
- **NEW:**   user_subnets_text line editor: same as domains
- **NEW:**   Sections menu: active section shown in header only (no spinning button)
