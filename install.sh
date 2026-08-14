#!/bin/ash

# Installer for podkop_bot — Telegram remote management bot for podkop/sing-box on OpenWrt
# Supports: OpenWrt 23.05 / 24.10 (opkg) and OpenWrt 25.x+ (apk)
# Supports podkop variants: original, evolution, netshift, podkop-plus, forkop (auto-detected)
# Based on installer pattern from https://github.com/VizzleTF/podkop_autoupdater
#
# CORRECT install command:
#   wget -O /tmp/install_podkop_bot.sh \
#     https://raw.githubusercontent.com/Medvedolog/podkop_bot/main/install.sh
#   ash /tmp/install_podkop_bot.sh
#
# UNATTENDED mode (for luci-app-podkop-bot backend, scripted installs, CI):
#   ash install.sh --unattended --action install --config /tmp/podkop_bot_install.json
#   ash install.sh --unattended --action update
#   ash install.sh --unattended --action uninstall
#   ash install.sh --unattended --action status
#   ash install.sh --unattended --action check
#   See UNATTENDED CONFIG FORMAT comment below for the JSON schema.
#
# INSTALLER_VERSION="2.6.1"
#
# CHANGELOG v2.6.1:
# - FIXED: the "podkop is not installed" menu still offered Podkop Plus from
#        ushan0v/podkop-plus, the repository that was renamed to forkop. A fresh
#        router was therefore pointed at the old name while the rest of this
#        installer already detects Forkop first (detect_podkop_variant) and the
#        bot itself refuses to let an "update" silently migrate a Plus box to
#        Forkop. The menu now offers Forkop at ushan0v/forkop.
#        Detection is unchanged: an existing Podkop Plus installation is still
#        recognised as "plus" and stays fully supported — only the fresh-install
#        recommendation moved to the maintained successor.
#
# INSTALLER_VERSION="2.6.0"
#
# CHANGELOG v2.5.1:
# - FIXED: _curl_socks_fallover now passes -L (follow redirects). GitHub
#        release-asset URLs 302-redirect to objects.githubusercontent.com;
#        without -L the download body was empty ("Downloaded file is empty"),
#        so --action update-luci / --with-luci could never fetch the .ipk/.apk.
#        Harmless for non-redirecting URLs (releases API, raw.githubusercontent).
#
# INSTALLER_VERSION="2.5.0"
#
# CHANGELOG v2.5.0:
# - ADDED: `--action update-luci` and `--with-luci` flag. Installs/updates the
#        luci-app-podkop-bot web UI: fetches the latest release asset for the
#        active package manager (opkg->.ipk, apk->.apk) from GitHub with the
#        usual direct->SOCKS fallback, then installs it DETACHED (setsid) so an
#        rpcd restart triggered by the install can't abort it. Progress is
#        written to /tmp/podkop_bot_luci_update.log (polled by the UI).
# - ADDED: after a bot install/update, the script now offers to install the
#        web UI too (interactive prompt; unattended via --with-luci). Single
#        entry point for the whole stack.
# - GUARD: update-luci fails loudly if curl is absent (bare system) instead of
#        hanging; on a router with the bot installed curl is always present.
#
# INSTALLER_VERSION="2.4.2"
#
# CHANGELOG v2.4.2:
# - Misc fixes carried from the luci-app work (log mojibake via printf
#   placeholders, /proc scan race, section-aware paths). Version bump to keep
#   the vendored copy in luci-app-podkop-bot in sync with the bot repo.
#
# INSTALLER_VERSION="2.4.1"
#
# CHANGELOG v2.4.1:
# - FIXED: _podkop_uci_pkg() mapped netshift -> "podkop" (wrong UCI namespace).
#        NetShift lives in the `netshift` namespace; detection already knew the
#        variant but the mapping dropped it. Now plus->podkop-plus,
#        netshift->netshift, *->podkop. (Same bug fixed in the rpcd backend.)
#
# INSTALLER_VERSION="2.4.0"
#
# CHANGELOG v2.4.0:
# - FIXED: msg() ate %s/%d placeholders. Branches printed their format with
#        printf "literal-with-%s", so $(msg X) executed that printf with no
#        argument and the placeholder vanished before any caller could
#        substitute — every version/path/count in install logs came out blank
#        ("Installed: v", "Config: /etc/config/", "Downloading bot v..."). All
#        54 placeholder-bearing msg branches now emit their format verbatim via
#        printf '%s' "literal", so both single- and double-printf callsites
#        substitute correctly. Non-placeholder messages and callsites with an
#        immediate argument were left untouched.
#
# INSTALLER_VERSION="2.3.3"
#
# CHANGELOG v2.3.3:
# - FIXED: /proc cmdline scan in _bot_alive() and _reap_bot_forks() leaked
#        "can't open /proc/PID/cmdline: no such file" to stderr when a process
#        exited mid-scan (race). The redirect-open error came from the shell
#        setting up "< /proc/PID/cmdline", which the inner 2>/dev/null on tr did
#        not catch. Wrapped the read in a subshell so the redirect error is
#        suppressed too. Cosmetic (scan still works), but kept the log clean.
# - KNOWN ISSUE (not fixed here): update-flow summary prints empty version /
#        config fields ("Installed: v", "Config: /etc/config/"). Root cause is
#        the msg() helper executing printf '...%s' with no argument, which eats
#        the %s before the caller can substitute. Affects ~71 %s-bearing
#        messages; needs a dedicated pass converting those msg branches to
#        printf '%s' "literal-with-%s". Deferred to avoid a risky broad change.
#
# INSTALLER_VERSION="2.3.2"
#
# CHANGELOG v2.3.2:
# - FIXED: read-only actions (status, check, check-token) no longer acquire the
#        installer lock. check-token does a network getMe (seconds) and the
#        Wizard may call it repeatedly; locking made it hang on — or get blocked
#        by — a stale/concurrent install lock for no reason.
# - FIXED: _release_lock now only releases a lock THIS process acquired
#        (_LOCK_HELD guard). Previously the EXIT trap of a read-only action would
#        remove a lock held by a concurrent install/update — so running the
#        Wizard's token check during an install could yank that install's lock.
#
# INSTALLER_VERSION="2.3.1"
#
# CHANGELOG v2.3.1:
# - FIXED: --action check-token printed the startup banner + variant-detection
#        log BEFORE its JSON, so callers parsing the output saw non-JSON and
#        treated a valid token as installer_error. check-token now joins the
#        _QUIET_STATUS fd3 guard (like status/check): banner/log go to /dev/null
#        and only the JSON result is emitted on the restored stdout.
#
# INSTALLER_VERSION="2.3.0"
#
# CHANGELOG v2.3.0:
# - NEW: --action check-token for the LuCI Setup Wizard (TZ 9.4). Validates a
#        bot token via Telegram getMe using the same _curl_socks_fallover
#        transport as the installer (direct -> SOCKS tiers), so validation works
#        behind ISP blocks instead of a naive direct curl. Reads bot_token from
#        --config; emits a flat JSON result on fd: {valid:true,username,route} or
#        {valid:false,reason,detail} with reason in
#        empty_token|token_invalid|telegram_unreachable|network_timeout. No
#        mutation, network-only, runs before heavy init.
#
# INSTALLER_VERSION="2.2.0"
# INSTALLER_VERSION="2.2.0"
#
# CHANGELOG v2.2.0:
# - NEW: Legacy init.d auto-heal on update. Bot <=0.15.1 shipped a procd-only
#        init with no stop_service and no fork cleanup; `init stop` left forked
#        children (health daemon + startup-notify poll) alive, so repeated
#        updates/respawns accumulated zombie instances (seen up to 6) fighting
#        over the Telegram API (409 Conflict / getUpdates race). The update flow
#        now: (1) reaps all live /usr/bin/podkop_bot forks BEFORE swapping the
#        binary via _reap_bot_forks (kill → wait → kill -9 → clear pidfile);
#        (2) detects a legacy init via _init_is_legacy (marker: absence of the
#        _kill_all_podkop_bot function) and force-replaces it with the canonical
#        working init via _write_working_init, backed up to .bak under the same
#        rollback umbrella as the binary.
# - NEW: _write_working_init() is now the single source of the init.d body —
#        both first-install and update call it, so the generated init can't
#        drift between flows. Carries _kill_all_podkop_bot in both start_service
#        and stop_service.
# - CHANGED: post-(re)start verification in the update flow uses _bot_alive (a
#        /proc scan) instead of `init status`, which lies on legacy scripts;
#        rollback uses _reap_bot_forks instead of `init stop`.
#
# INSTALLER_VERSION="2.1.1"
#
# CHANGELOG v2.1.1:
# - FIXED: --action status running-state detection no longer trusts
#        `/etc/init.d/podkop_bot status`. Routers running bot <=0.15.1 shipped
#        incomplete init.d scripts whose status returns 0 even when the process
#        is dead, so status reported running:true on a stopped bot (and
#        luci-app-podkop-bot then showed a green lamp on a dead bot). Liveness
#        is now read from a /proc cmdline scan for /usr/bin/podkop_bot, with the
#        init wrapper and rc.common excluded. The pidfile check remains as a
#        secondary fallback. Same detection method luci-app-podkop-bot's rpcd
#        backend now uses, keeping one source of truth across the project.
#
# INSTALLER_VERSION="2.1.0"
#
# CHANGELOG v2.1.0:
# - NEW: Offline bootstrap fallback. download_file() and download_file_optional()
#        try a vendored local copy as a final tier, after direct + SOCKS are
#        exhausted. Copies live in $VENDOR_DIR (/usr/lib/podkop_bot), matched by
#        URL basename (podkop_bot.sh→podkop_bot, podkop_bot_init→podkop_bot_init).
#        Lets the bot install where raw.githubusercontent.com is blocked and no
#        SOCKS exists yet — the primary case for an anti-censorship tool. The
#        luci-app-podkop-bot package ships these copies, making the system a
#        self-contained offline bootstrap. Pure headless run (no LuCI package) →
#        $VENDOR_DIR absent, tier skipped, behaviour identical to v2.0.0.
# - NOTE: Vendored copies reflect bot version at package build time; online
#        install/update always prefers the network copy.
#
# INSTALLER_VERSION="2.0.0"
#
# CHANGELOG v2.0.0:
# - NEW: Podkop variant auto-detection (original / evolution / netshift / plus).
#        Detected via UCI field fingerprint (action= vs connection_type=,
#        presence of Plus-only fields) plus binary/package signature. Variant
#        is shown in the pre-flight summary and used to pick the correct UCI
#        field names for SOCKS tier1 discovery.
# - NEW: _get_socks_endpoints() rewritten to support all 4 variants. Original/
#        evolution/netshift use connection_type=proxy; Plus uses action=proxy.
#        Previously only the legacy connection_type schema was checked, so
#        tier1 fallback silently returned nothing on any Plus install — the
#        installer had no transport to fall back on if GitHub was blocked
#        during a *first* install (no fallback_socks configured yet either).
# - NEW: Bilingual UI (English / Russian). Language chosen interactively at
#        startup, or via --lang en|ru / unattended config "lang". All prompts,
#        warnings and summary text are now routed through a tiny message
#        table (msg()) instead of hardcoded English strings.
# - NEW: Verbose, multi-line explanations before every interactive prompt —
#        what the setting does, why it matters, and what happens with each
#        choice — instead of a single terse question line.
# - NEW: --unattended mode with --action install|update|uninstall|status|check
#        and --config <path-to-json>. Lock file prevents concurrent runs.
#        Designed for luci-app-podkop-bot's rpcd backend to call this script
#        without any TTY interaction. See schema comment below.
# - NEW: Expanded final summary: shows detected podkop variant, podkop/sing-box
#        versions, where every file lives, and a "recommended next steps"
#        block — explains *why* Mixed Proxy matters and clarifies that YACD
#        exact LuCI paths, rather than just listing useful commands.
#
# CHANGELOG v1.9.0:
# - NEW: _get_socks_endpoints() reads tier1 (podkop mixed_proxy) and fallback_socks
#        from UCI — works before bot starts, no bot variables needed.
# - NEW: _curl_socks_fallover() wraps curl with automatic SOCKS fallover:
#        direct → tier1 → each tier2_N. Used by version check and token validation.
# - NEW: download_file() now tries SOCKS tiers after direct wget/curl fail.
#        Prints "Downloaded via socks5h://..." when proxy was used.
# - NEW: Token validation (getMe) uses _curl_socks_fallover — works behind ISP blocks.
# - NEW: Version check uses _curl_socks_fallover instead of separate wget/curl fallback.
#
# CHANGELOG v1.8.0:
# - FIXED: safe_stop_bot() now reads PID from /tmp/podkop_bot/bot.pid (new BOT_DIR
#          path since v0.14.1), with fallback to legacy /tmp/podkop_bot.pid for
#          older installs. Previously always missed the PID and relied solely on
#          killall -9 as a safety net.
# - FIXED: cleanup_bot_runtime_files() rewritten to cover both new BOT_DIR paths
#          (/tmp/podkop_bot/*) and legacy flat paths (/tmp/podkop_bot_*) so it
#          works correctly after upgrade, downgrade, or fresh install.
# - FIXED: Uninstall (option 4) now also removes /tmp/podkop_bot/ directory,
#          leaving no artifacts after complete removal.
#
# CHANGELOG v1.7.0:
# - NEW:  Option 4 — full uninstall with double confirmation (type "YES" then
#         "REMOVE"). Removes: bot binary, init.d script, /etc/config/podkop_bot
#         (token, chat_id, all settings), all /tmp runtime files.
#         podkop and sing-box are NOT touched. Useful for clean reinstall or
#         permanent removal.
#
# CHANGELOG v1.6.0:
# - FIXED: download_file() now uses --connect-timeout 10 --max-time 30 on curl
#          and -T 15 on wget. BusyBox wget hangs indefinitely without -T when
#          DNS or network is slow/broken (hit in practice on flaky WAN).
# - FIXED: cleanup_bot_runtime_files() list now includes /tmp/podkop_bot_active_section,
#          /tmp/podkop_cl_cache* and /tmp/podkop_pubip_cache.txt — all files the
#          bot creates on first run that carry section/cache state between versions.
# - FIXED: validate_socks_url() now rejects port > 65535 (was only checking
#          digit count, not value). Added awk numeric range check.
# - IMPROVED: pkg_update() failure is now a warning, not a hard die() — on some
#             routers with stale feeds the update fails but the package is already
#             installed. Installer continues with a warning instead of aborting.
#
# CHANGELOG v1.5.0:
# - NEW:  safe_stop_bot now calls cleanup_bot_runtime_files() (Step 5) which
#         removes all /tmp/podkop_bot_* IPC/state files before deploying new binary.
#         Prevents stale route keys, nudge timestamps, socks state from old versions
#         polluting the new bot startup (root cause of 'tir4' mystery).
#
# CHANGELOG v1.4.0:
# - FIXED: vv0.7.14-r1 → v0.7.14-r1: opkg returns version with leading 'v',
#          installer was adding another via "v${PODKOP_VER}". Added sed strip.
# - FIXED: Update flow now shows full summary (version, path, useful commands)
#          instead of bare "Done." + exit 0 before summary block.
#
# CHANGELOG v1.3.0:
# - NEW:  safe_stop_bot(): kill by PID file + killall -9 before binary replacement.
#         Prevents zombie watchdog subshells surviving update.
# - NEW:  podkop presence check with version display before install.
# - NEW:  admin_ids configured via uci add_list (fixes space-separated breakage).
# - NEW:  Fallback SOCKS configuration in interactive setup.
#
# CHANGELOG v1.2.0:
# - NEW:  Detect accidental HTML download (wrong GitHub blob URL) and show correct
#         raw.githubusercontent.com URL with clear error message.
# - NEW:  apk package manager support for OpenWrt 25.x+.
#
# CHANGELOG v1.1.0:
# - NEW:  Update flow: detect existing install, show token/version, offer
#         update-keep-config / reinstall / exit options.
# - NEW:  init.d script download and installation.
# - NEW:  Verbose progress output throughout.
#
# ─────────────────────────────────────────────────────────────────────────────
# UNATTENDED CONFIG FORMAT (JSON, read with jq when --config is given)
# ─────────────────────────────────────────────────────────────────────────────
# {
#   "lang": "en",                          // "en" or "ru", default "en"
#   "bot_token": "123456:ABC-DEF...",       // required for install
#   "chat_id": "123456789",                 // required for install
#   "admin_ids": "111111 222222",           // optional, space-separated
#   "allow_anonymous_admins": "1",          // "0" or "1", default "1"
#   "fallback_socks": "socks5h://10.0.0.5:18088 socks5h://10.0.0.6:1080",
#   "setup_init": "1",                      // "0" or "1", default "1"
#   "start_now": "1"                        // "0" or "1", default "1"
# }
#
# Exit codes (unattended mode):
#   0  success
#   2  bad arguments / usage error
#   10 lock file present (another instance running)
#   11 not running on OpenWrt/ImmortalWrt
#   12 missing required config field (bot_token / chat_id)
#   13 config file missing or invalid JSON
#   14 dependency install failed (curl/jq)
#   15 download failed (bot script / init script) — no transport available
#   16 UCI write/commit failed
#   17 token validation failed (network reachable but Telegram rejected token)
#   18 service start failed
#   19 uninstall confirmation mismatch (should not occur in unattended mode —
#      unattended uninstall skips the YES/REMOVE prompts by design)
#
# ── Restrictive umask: config files (token!) must not be world-readable ───────
# Set before any touch/mktemp/uci write so newly-created files default to 0600.
umask 077

# ── Self-check: detect accidental HTML download (wrong GitHub URL) ─────────────
# Correct:  https://raw.githubusercontent.com/...
# Wrong:    https://github.com/.../blob/main/...  -- downloads HTML page
_first_line=$(head -1 "$0" 2>/dev/null)
case "$_first_line" in
    '<!DOCTYPE'*|'<html'*)
        echo ""
        echo "ERROR: Downloaded HTML page instead of shell script."
        echo "Use the raw URL:"
        echo ""
        echo "  wget -O /tmp/install_podkop_bot.sh \\"
        echo "    https://raw.githubusercontent.com/Medvedolog/podkop_bot/main/install.sh"
        echo "  ash /tmp/install_podkop_bot.sh"
        echo ""
        exit 1
        ;;
esac
unset _first_line

# ── Constants ──────────────────────────────────────────────────────────────────
INSTALLER_VERSION="2.6.1"
BOT_URL="https://raw.githubusercontent.com/Medvedolog/podkop_bot/main/podkop_bot.sh"
VERSION_URL="https://raw.githubusercontent.com/Medvedolog/podkop_bot/main/version.txt"
BOT_PATH="/usr/bin/podkop_bot"
INIT_PATH="/etc/init.d/podkop_bot"
INIT_URL="https://raw.githubusercontent.com/Medvedolog/podkop_bot/main/podkop_bot_init"
# Vendored fallback copies shipped inside luci-app-podkop-bot (.ipk/.apk). Used
# as a LAST-resort transport tier in download_file()/download_file_optional()
# when direct + SOCKS all fail — enables offline bootstrap of the bot when
# GitHub is blocked (primary case for an anti-censorship tool). Matched to a URL
# by basename, so one tier covers both bot body and init.d. Absent on a pure
# headless install → tier skipped, behaviour unchanged.
VENDOR_DIR="/usr/lib/podkop_bot"
UCI_PKG="podkop_bot"
UCI_SEC="settings"
OS_RELEASE_FILE="/etc/os-release"
TOKEN_DISPLAY_LENGTH=10
LOCK_DIR="/tmp/podkop_bot_installer.lock"
_PROXY_BOOTSTRAPPED=0

# ── Parse CLI arguments ───────────────────────────────────────────────────────
# Supported forms:
#   ash install.sh                                   interactive (default)
#   ash install.sh --lang ru                          interactive, RU forced
#   ash install.sh --unattended --action <a> [--config <path>]
UNATTENDED=0
UA_ACTION=""
UA_CONFIG=""
UA_WITH_LUCI=0
LANG_FORCED=""

while [ $# -gt 0 ]; do
    case "$1" in
        --unattended)     UNATTENDED=1; shift ;;
        --action)         UA_ACTION="$2"; shift 2 ;;
        --with-luci)      UA_WITH_LUCI=1; shift ;;
        --config)         UA_CONFIG="$2"; shift 2 ;;
        --lang)           LANG_FORCED="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--lang en|ru]"
            echo "       $0 --unattended --action install|update|uninstall|status|check [--config <path>]"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            echo "Usage: $0 [--lang en|ru] | --unattended --action <action> [--config <path>]"
            exit 2
            ;;
    esac
done

if [ "$UNATTENDED" = "1" ]; then
    case "$UA_ACTION" in
        install|update|uninstall|status|check|check-token|update-luci) ;;
        *)
            echo "ERROR: --unattended requires --action install|update|uninstall|status|check|check-token|update-luci"
            exit 2
            ;;
    esac
fi

# ── Helpers ────────────────────────────────────────────────────────────────────
die()     { echo "" >&2; echo "ERROR: $1" >&2; _release_lock; exit "${2:-1}"; }
info()    { echo "  $1"; }
ok()      { echo "[OK] $1"; }
warn()    { echo "[!!] $1"; }
step()    { echo ""; echo ">>> $1"; }
section() { echo ""; echo "-------------------------------------------"; echo "  $1"; echo "-------------------------------------------"; echo ""; }

_LOCK_HELD=0
_acquire_lock() {
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "ERROR: Another installer instance is already running (lock: $LOCK_DIR)."
        echo "If this is stale (previous run crashed), remove it manually:"
        echo "  rmdir $LOCK_DIR"
        exit 10
    fi
    _LOCK_HELD=1
    echo "$$" > "$LOCK_DIR/pid" 2>/dev/null || true
}
# Only release a lock THIS process acquired. Read-only actions (status / check /
# check-token) never acquire it, so their EXIT trap must not remove a lock held
# by a concurrent install/update — otherwise running the Wizard's token check
# during an install would yank that install's lock out from under it.
_release_lock() { [ "$_LOCK_HELD" = "1" ] || return 0; rmdir "$LOCK_DIR" 2>/dev/null || rm -rf "$LOCK_DIR" 2>/dev/null || true; _LOCK_HELD=0; }
trap '_teardown_user_proxy; _release_lock' EXIT
trap '_teardown_user_proxy; _release_lock; exit 130' INT
trap '_teardown_user_proxy; _release_lock; exit 143' TERM

# ── i18n: minimal message table, English default, Russian alternate ──────────
# UI_LANG is "en" or "ru". Resolution order: --lang flag > unattended config
# "lang" field > interactive prompt > default "en".
UI_LANG="en"

# msg(): looks up a key, returns the string for UI_LANG (falls back to en).
# Usage: msg key_name
# Multi-line strings use \n inside the case branch — printf interprets it.
msg() {
    case "$1" in
        ask_lang) case "$UI_LANG" in
            *) printf 'Choose installer language / Выберите язык установщика:\n  1) English\n  2) Русский\n> ' ;;
            esac ;;

        title) case "$UI_LANG" in
            ru) printf "  podkop_bot — установщик" ;;
            *)  printf "  podkop_bot installer" ;;
            esac ;;

        detecting_variant) case "$UI_LANG" in
            ru) printf "Определение варианта podkop..." ;;
            *)  printf "Detecting podkop variant..." ;;
            esac ;;

        variant_label_original) case "$UI_LANG" in
            ru) printf "оригинальный podkop" ;;
            *)  printf "original podkop" ;;
            esac ;;
        variant_label_evolution) case "$UI_LANG" in
            ru) printf "Podkop Evolution" ;;
            *)  printf "Podkop Evolution" ;;
            esac ;;
        variant_label_netshift) case "$UI_LANG" in
            ru) printf "Podkop NetShift" ;;
            *)  printf "Podkop NetShift" ;;
            esac ;;
        variant_label_plus) case "$UI_LANG" in
            ru) printf "Podkop Plus" ;;
            *)  printf "Podkop Plus" ;;
            esac ;;
        variant_label_unknown) case "$UI_LANG" in
            ru) printf "не определён" ;;
            *)  printf "undetermined" ;;
            esac ;;

        podkop_not_found) case "$UI_LANG" in
            ru) printf "Похоже, podkop не установлен на этом роутере." ;;
            *)  printf "podkop does not appear to be installed on this system." ;;
            esac ;;
        podkop_required) case "$UI_LANG" in
            ru) printf "podkop_bot требует podkop для работы." ;;
            *)  printf "podkop_bot requires podkop to function." ;;
            esac ;;
        continue_anyway) case "$UI_LANG" in
            ru) printf "Продолжить установку без podkop? (y/N): " ;;
            *)  printf "Continue installation anyway? (y/N): " ;;
            esac ;;
        install_aborted) case "$UI_LANG" in
            ru) printf "Установка прервана. Сначала установите podkop." ;;
            *)  printf "Installation aborted. Install podkop first." ;;
            esac ;;

        os_check_fail) case "$UI_LANG" in
            ru) printf "Этот скрипт предназначен только для OpenWrt / ImmortalWrt." ;;
            *)  printf "This script is designed for OpenWrt / ImmortalWrt only." ;;
            esac ;;

        downloading_deps) case "$UI_LANG" in
            ru) printf "Установка зависимостей..." ;;
            *)  printf "Installing dependencies..." ;;
            esac ;;
        updating_index) case "$UI_LANG" in
            ru) printf "Обновление индекса пакетов..." ;;
            *)  printf "Updating package index..." ;;
            esac ;;
        index_update_failed) case "$UI_LANG" in
            ru) printf "Обновление индекса пакетов не удалось — используем кэш." ;;
            *)  printf "Package index update failed — continuing with cached index." ;;
            esac ;;

        existing_detected) case "$UI_LANG" in
            ru) printf "Обнаружена существующая установка:" ;;
            *)  printf "Existing installation detected:" ;;
            esac ;;
        menu_intro) case "$UI_LANG" in
            ru) printf "Что вы хотите сделать?" ;;
            *)  printf "What would you like to do?" ;;
            esac ;;
        menu_1) case "$UI_LANG" in
            ru) printf "  1) Обновить podkop_bot до последней версии, настройки сохранятся  [по умолчанию]" ;;
            *)  printf "  1) Update podkop_bot to latest version, keep settings  [default]" ;;
            esac ;;
        menu_2) case "$UI_LANG" in
            ru) printf "  2) Переустановить podkop_bot с новыми настройками (токен, chat ID и т.д.)" ;;
            *)  printf "  2) Reinstall podkop_bot with new settings (token, chat ID, etc.)" ;;
            esac ;;
        menu_3) case "$UI_LANG" in
            ru) printf "  3) Выйти без изменений" ;;
            *)  printf "  3) Exit without changes" ;;
            esac ;;
        menu_4) case "$UI_LANG" in
            ru) printf "  4) Полностью удалить podkop_bot" ;;
            *)  printf "  4) Uninstall podkop_bot completely" ;;
            esac ;;
        menu_prompt) case "$UI_LANG" in
            ru) printf "Введите 1, 2, 3 или 4: " ;;
            *)  printf "Enter 1, 2, 3 or 4: " ;;
            esac ;;

        owrt_version) case "$UI_LANG" in
            ru) printf "Версия OpenWrt  " ;;
            *)  printf "OpenWrt version " ;;
            esac ;;
        pkg_manager_label) case "$UI_LANG" in
            ru) printf "Менеджер пакетов" ;;
            *)  printf "Package manager " ;;
            esac ;;
        hostname_label) case "$UI_LANG" in
            ru) printf "Имя хоста       " ;;
            *)  printf "Hostname        " ;;
            esac ;;

        podkop_install_first) case "$UI_LANG" in
            ru) printf "Сначала установите podkop. Выберите нужный вариант, затем запустите установщик снова." ;;
            *)  printf "Install podkop first. Pick the variant you want, then re-run this installer." ;;
            esac ;;
        podkop_variant_original) case "$UI_LANG" in
            ru) printf "Оригинальный (itdoginfo/podkop) — рекомендуемая база:" ;;
            *)  printf "Original (itdoginfo/podkop) — recommended baseline:" ;;
            esac ;;
        podkop_variant_netshift_line) case "$UI_LANG" in
            ru) printf "NetShift (yandexru45/netshift — ранее podkop-evolution; подписки, HWID):" ;;
            *)  printf "NetShift (yandexru45/netshift — formerly podkop-evolution; subscriptions, HWID):" ;;
            esac ;;
        podkop_variant_forkop_line) case "$UI_LANG" in
            ru) printf "Forkop (ushan0v/forkop — преемник Podkop Plus; zapret/byedpi, серверный режим):" ;;
            *)  printf "Forkop (ushan0v/forkop — successor to Podkop Plus; zapret/byedpi, server mode):" ;;
            esac ;;
        # Kept for compatibility: still referenced by older translations//flows.
        # Podkop Plus was renamed to Forkop; fresh installs are offered Forkop
        # above, but an already-installed Plus box stays fully supported and is
        # still detected as "plus" by detect_podkop_variant().
        podkop_variant_plus_line) case "$UI_LANG" in
            ru) printf "Podkop Plus (переименован в Forkop; для уже установленных систем):" ;;
            *)  printf "Podkop Plus (renamed to Forkop; for existing installations):" ;;
            esac ;;
        podkop_docs_line) case "$UI_LANG" in
            ru) printf "Документация по всем вариантам: https://podkop.net/docs/install/" ;;
            *)  printf "Docs for all variants: https://podkop.net/docs/install/" ;;
            esac ;;
        unattended_no_podkop) case "$UI_LANG" in
            ru) printf "Unattended-режим: продолжаем без podkop (большая часть функций бота не будет работать)." ;;
            *)  printf "Unattended mode: continuing without podkop (most bot features won't work)." ;;
            esac ;;
        continuing_no_podkop) case "$UI_LANG" in
            ru) printf "Продолжаем без podkop — бот запустится, но большая часть функций не будет работать." ;;
            *)  printf "Continuing without podkop — bot will start but most features won't work." ;;
            esac ;;
        podkop_found) case "$UI_LANG" in
            ru) printf "podkop найден" ;;
            *)  printf "podkop found" ;;
            esac ;;
        variant_word) case "$UI_LANG" in
            ru) printf "вариант" ;;
            *)  printf "variant" ;;
            esac ;;

        token_label) case "$UI_LANG" in
            ru) printf "Токен    " ;;
            *)  printf "Token    " ;;
            esac ;;
        chat_id_label) case "$UI_LANG" in
            ru) printf "Chat ID  " ;;
            *)  printf "Chat ID  " ;;
            esac ;;
        version_label) case "$UI_LANG" in
            ru) printf "Версия   " ;;
            *)  printf "Version  " ;;
            esac ;;
        existing_install_to_update) case "$UI_LANG" in
            ru) printf "Найдена существующая установка — unattended 'install' поверх неё работает как 'update'." ;;
            *)  printf "Existing installation found — unattended 'install' on top of it behaves as 'update'." ;;
            esac ;;

        reinstalling) case "$UI_LANG" in
            ru) printf "Переустановка с новыми настройками..." ;;
            *)  printf "Reinstalling with new settings..." ;;
            esac ;;
        skipped_kept) case "$UI_LANG" in
            ru) printf "Пропущено. Существующий конфиг сохранён." ;;
            *)  printf "Skipped. Existing config preserved." ;;
            esac ;;

        uninstall_title) case "$UI_LANG" in
            ru) printf "  УДАЛЕНИЕ podkop_bot" ;;
            *)  printf "  UNINSTALL podkop_bot" ;;
            esac ;;
        uninstall_will_remove) case "$UI_LANG" in
            ru) printf "Будет удалено:" ;;
            *)  printf "This will remove:" ;;
            esac ;;
        uninstall_item_bin) case "$UI_LANG" in
            ru) printf '%s' "  - Бинарь бота      : %s" ;;
            *)  printf '%s' "  - Bot binary       : %s" ;;
            esac ;;
        uninstall_item_init) case "$UI_LANG" in
            ru) printf '%s' "  - Скрипт init.d    : %s" ;;
            *)  printf '%s' "  - Init.d script    : %s" ;;
            esac ;;
        uninstall_item_uci) case "$UI_LANG" in
            ru) printf '%s' "  - UCI-конфиг       : /etc/config/%s" ;;
            *)  printf '%s' "  - UCI config       : /etc/config/%s" ;;
            esac ;;
        uninstall_item_uci_detail) case "$UI_LANG" in
            ru) printf "    (bot_token, chat_id, fallback_socks, все настройки)" ;;
            *)  printf "    (bot_token, chat_id, fallback_socks, all settings)" ;;
            esac ;;
        uninstall_item_tmp) case "$UI_LANG" in
            ru) printf "  - Все временные файлы в /tmp" ;;
            *)  printf "  - All /tmp runtime files" ;;
            esac ;;
        uninstall_not_touched) case "$UI_LANG" in
            ru) printf "Сам podkop и его конфиг НЕ будут затронуты." ;;
            *)  printf "podkop itself and its config will NOT be touched." ;;
            esac ;;
        uninstall_type_yes) case "$UI_LANG" in
            ru) printf "Введите YES для подтверждения удаления: " ;;
            *)  printf "Type YES to confirm uninstall: " ;;
            esac ;;
        uninstall_cancelled) case "$UI_LANG" in
            ru) printf "Удаление отменено." ;;
            *)  printf "Uninstall cancelled." ;;
            esac ;;
        uninstall_type_remove) case "$UI_LANG" in
            ru) printf "Вы уверены? Введите REMOVE чтобы продолжить: " ;;
            *)  printf "Are you sure? Type REMOVE to proceed: " ;;
            esac ;;
        stopping_bot_service) case "$UI_LANG" in
            ru) printf "Останавливаем сервис бота..." ;;
            *)  printf "Stopping bot service..." ;;
            esac ;;
        removed) case "$UI_LANG" in
            ru) printf '%s' "Удалено: %s" ;;
            *)  printf '%s' "Removed %s" ;;
            esac ;;
        removing_bot_binary) case "$UI_LANG" in
            ru) printf "Удаляем бинарь бота..." ;;
            *)  printf "Removing bot binary..." ;;
            esac ;;
        removing_uci_config) case "$UI_LANG" in
            ru) printf "Удаляем UCI-конфиг..." ;;
            *)  printf "Removing UCI config..." ;;
            esac ;;
        cleaning_runtime) case "$UI_LANG" in
            ru) printf "Чистим временные файлы..." ;;
            *)  printf "Cleaning up runtime files..." ;;
            esac ;;
        uninstall_complete) case "$UI_LANG" in
            ru) printf "  Удаление завершено." ;;
            *)  printf "  Uninstall complete." ;;
            esac ;;
        podkop_untouched_running) case "$UI_LANG" in
            ru) printf "podkop и sing-box не затронуты и продолжают работать." ;;
            *)  printf "podkop and sing-box are untouched and running." ;;
            esac ;;
        reinstall_later) case "$UI_LANG" in
            ru) printf "Чтобы установить бота снова, запустите установщик ещё раз." ;;
            *)  printf "To reinstall later, run the installer again." ;;
            esac ;;

        checking_updates) case "$UI_LANG" in
            ru) printf "Проверяем обновления..." ;;
            *)  printf "Checking for updates..." ;;
            esac ;;
        installed_label) case "$UI_LANG" in
            ru) printf '%s' "  Установлено : v%s" ;;
            *)  printf '%s' "  Installed : v%s" ;;
            esac ;;
        available_label) case "$UI_LANG" in
            ru) printf '%s' "  Доступно    : v%s" ;;
            *)  printf '%s' "  Available : v%s" ;;
            esac ;;
        already_up_to_date_noninteractive) case "$UI_LANG" in
            ru) printf "Уже последняя версия. Изменений не внесено." ;;
            *)  printf "Already up to date. No changes made." ;;
            esac ;;
        already_up_to_date) case "$UI_LANG" in
            ru) printf "Уже последняя версия." ;;
            *)  printf "Already up to date." ;;
            esac ;;
        update_anyway) case "$UI_LANG" in
            ru) printf "Обновить всё равно? (y/N): " ;;
            *)  printf "Update anyway? (y/N): " ;;
            esac ;;
        no_changes_made) case "$UI_LANG" in
            ru) printf "Изменений не внесено." ;;
            *)  printf "No changes made." ;;
            esac ;;
        update_confirm) case "$UI_LANG" in
            ru) printf '%s' "Обновить v%s -> v%s? (Y/n): " ;;
            *)  printf '%s' "Update v%s -> v%s? (Y/n): " ;;
            esac ;;
        update_cancelled) case "$UI_LANG" in
            ru) printf "Обновление отменено." ;;
            *)  printf "Update cancelled." ;;
            esac ;;
        downloading_bot_v) case "$UI_LANG" in
            ru) printf '%s' "  Скачиваем бота v%s... " ;;
            *)  printf '%s' "  Downloading bot v%s... " ;;
            esac ;;
        updating_init) case "$UI_LANG" in
            ru) printf "  Обновляем init.d-скрипт... " ;;
            *)  printf "  Updating init.d script... " ;;
            esac ;;
        updated_to_v) case "$UI_LANG" in
            ru) printf '%s' "Обновлено до v%s." ;;
            *)  printf '%s' "Updated to v%s." ;;
            esac ;;
        starting_service) case "$UI_LANG" in
            ru) printf "  Запускаем сервис... " ;;
            *)  printf "  Starting service... " ;;
            esac ;;
        service_restarted_ok) case "$UI_LANG" in
            ru) printf "Сервис перезапущен успешно." ;;
            *)  printf "Service restarted successfully." ;;
            esac ;;
        no_init_start_manually) case "$UI_LANG" in
            ru) printf '%s' "Скрипт init.d не найден. Запустите вручную: %s &" ;;
            *)  printf '%s' "No init.d script found. Start manually: %s &" ;;
            esac ;;
        rollback_warn) case "$UI_LANG" in
            ru) printf "Новая версия не запустилась — откатываемся на предыдущий бинарь." ;;
            *)  printf "New version failed to start — rolling back to the previous binary." ;;
            esac ;;
        rollback_ok) case "$UI_LANG" in
            ru) printf "Откат выполнен — предыдущая версия снова работает." ;;
            *)  printf "Rolled back to the previous version — it is running again." ;;
            esac ;;
        rollback_also_failed) case "$UI_LANG" in
            ru) printf "Откат восстановил предыдущий бинарь, но он тоже не запустился." ;;
            *)  printf "Rollback restored the previous binary but it also failed to start." ;;
            esac ;;
        rollback_check_logs) case "$UI_LANG" in
            ru) printf "Проверьте: logread | grep podkop-bot" ;;
            *)  printf "Check: logread | grep podkop-bot" ;;
            esac ;;
        rollback_no_backup) case "$UI_LANG" in
            ru) printf '%s' "Резервная копия бинаря не найдена (%s отсутствует) — автоматический откат невозможен." ;;
            *)  printf '%s' "No backup binary found (%s missing) — could not roll back automatically." ;;
            esac ;;
        update_complete_title) case "$UI_LANG" in
            ru) printf "  Обновление завершено!" ;;
            *)  printf "  Update complete!" ;;
            esac ;;
        bot_script_label) case "$UI_LANG" in
            ru) printf '%s' "  Скрипт бота : %s" ;;
            *)  printf '%s' "  Bot script : %s" ;;
            esac ;;
        version_v_label) case "$UI_LANG" in
            ru) printf '%s' "  Версия      : v%s" ;;
            *)  printf '%s' "  Version    : v%s" ;;
            esac ;;
        config_label) case "$UI_LANG" in
            ru) printf '%s' "  Конфиг      : /etc/config/%s" ;;
            *)  printf '%s' "  Config     : /etc/config/%s" ;;
            esac ;;
        useful_commands) case "$UI_LANG" in
            ru) printf "Полезные команды:" ;;
            *)  printf "Useful commands:" ;;
            esac ;;
        live_logs_cmd) case "$UI_LANG" in
            ru) printf "  logread -f | grep podkop-bot          — логи в реальном времени" ;;
            *)  printf "  logread -f | grep podkop-bot          — live logs" ;;
            esac ;;
        restart_bot_cmd) case "$UI_LANG" in
            ru) printf "  /etc/init.d/podkop_bot restart        — перезапустить бота" ;;
            *)  printf "  /etc/init.d/podkop_bot restart        — restart bot" ;;
            esac ;;
        check_status_cmd) case "$UI_LANG" in
            ru) printf "  /etc/init.d/podkop_bot status         — проверить статус" ;;
            *)  printf "  /etc/init.d/podkop_bot status         — check status" ;;
            esac ;;

        uninstalling_unattended) case "$UI_LANG" in
            ru) printf "Удаляем podkop_bot (unattended)..." ;;
            *)  printf "Uninstalling podkop_bot (unattended)..." ;;
            esac ;;
        downloading_bot) case "$UI_LANG" in
            ru) printf "Скачиваем podkop_bot..." ;;
            *)  printf "Downloading podkop_bot..." ;;
            esac ;;
        downloaded_v) case "$UI_LANG" in
            ru) printf '%s' "Скачано v%s: %s" ;;
            *)  printf '%s' "Downloaded v%s: %s" ;;
            esac ;;
        section_bot_config) case "$UI_LANG" in
            ru) printf "Настройка бота" ;;
            *)  printf "Bot configuration" ;;
            esac ;;
        section_fallback_socks) case "$UI_LANG" in
            ru) printf "Резервные SOCKS-прокси (необязательно, но рекомендуется)" ;;
            *)  printf "Fallback SOCKS (optional but recommended)" ;;
            esac ;;
        section_autostart) case "$UI_LANG" in
            ru) printf "Автозапуск" ;;
            *)  printf "Autostart" ;;
            esac ;;
        writing_uci_config) case "$UI_LANG" in
            ru) printf "Записываем UCI-конфиг..." ;;
            *)  printf "Writing UCI config..." ;;
            esac ;;

        verifying_token) case "$UI_LANG" in
            ru) printf "  Проверяем токен... " ;;
            *)  printf "  Verifying token... " ;;
            esac ;;
        tg_direct_failed) case "$UI_LANG" in
            ru) printf "Не удалось напрямую достучаться до Telegram API." ;;
            *)  printf "Could not reach Telegram API — direct connection failed." ;;
            esac ;;
        tg_blocked_hint1) case "$UI_LANG" in
            ru) printf "Если Telegram заблокирован вашим провайдером, сначала включите Mixed Proxy в podkop:" ;;
            *)  printf "If Telegram is blocked by your ISP, enable Mixed Proxy in podkop first:" ;;
            esac ;;
        tg_blocked_hint2) case "$UI_LANG" in
            ru) printf "  LuCI → Podkop → Mixed Proxy Port → включить, затем перезапустить установщик." ;;
            *)  printf "  LuCI → Podkop → Mixed Proxy Port → enable, then re-run installer." ;;
            esac ;;
        tg_verify_failed_generic) case "$UI_LANG" in
            ru) printf "Не удалось проверить токен (проблема с сетью, неверный токен, или все SOCKS-тиры недоступны)." ;;
            *)  printf "Could not verify token (network issue, invalid token, or all SOCKS tiers failed)." ;;
            esac ;;
        continue_with_token) case "$UI_LANG" in
            ru) printf "Продолжить с этим токеном всё равно? (y/N): " ;;
            *)  printf "Continue with this token anyway? (y/N): " ;;
            esac ;;

        dl_direct_failed) case "$UI_LANG" in
            ru) printf "\n  [!!] Прямое соединение не удалось (возможно, GitHub блокируется вашим провайдером).\n" ;;
            *)  printf "\n  [!!] Direct connection failed (GitHub may be blocked by your ISP).\n" ;;
            esac ;;
        dl_no_socks_configured) case "$UI_LANG" in
            ru) printf "  [!!] SOCKS-прокси не настроен — фолбэк невозможен.\n" ;;
            *)  printf "  [!!] No SOCKS proxy configured — cannot try fallover.\n" ;;
            esac ;;
        dl_fix_mixed_proxy1) case "$UI_LANG" in
            ru) printf "  Решение: включите Mixed Proxy в podkop (LuCI → Podkop → Mixed Proxy Port),\n" ;;
            *)  printf "  To fix: enable Mixed Proxy in podkop (LuCI → Podkop → Mixed Proxy Port),\n" ;;
            esac ;;
        dl_fix_mixed_proxy2) case "$UI_LANG" in
            ru) printf "  затем перезапустите установщик.\n\n" ;;
            *)  printf "  then re-run this installer.\n\n" ;;
            esac ;;
        dl_trying_socks) case "$UI_LANG" in
            ru) printf "  Пробуем через SOCKS-тиры...\n" ;;
            *)  printf "  Trying via SOCKS tiers...\n" ;;
            esac ;;
        dl_failed_word) case "$UI_LANG" in
            ru) printf "ошибка\n" ;;
            *)  printf "failed\n" ;;
            esac ;;
        dl_all_socks_failed) case "$UI_LANG" in
            ru) printf "\n  [!!] Все SOCKS-тиры не сработали.\n" ;;
            *)  printf "\n  [!!] All SOCKS tiers failed.\n" ;;
            esac ;;
        dl_used_vendor) case "$UI_LANG" in
            ru) printf '%s' "    → использую встроенную офлайн-копию: %s\n" ;;
            *)  printf '%s' "    → using bundled offline copy: %s\n" ;;
            esac ;;
        dl_check_podkop_running) case "$UI_LANG" in
            ru) printf "  Проверьте, что podkop запущен и Mixed Proxy включён:\n" ;;
            *)  printf "  Check that podkop is running and Mixed Proxy is enabled:\n" ;;
            esac ;;
        dl_or_add_fallback) case "$UI_LANG" in
            ru) printf "  Либо добавьте резервный SOCKS-прокси и повторите попытку.\n\n" ;;
            *)  printf "  Or add a fallback SOCKS proxy and retry.\n\n" ;;
            esac ;;

        stopping_via_initd) case "$UI_LANG" in
            ru) printf "  Останавливаем через init.d... " ;;
            *)  printf "  Stopping via init.d... " ;;
            esac ;;
        done_word) case "$UI_LANG" in
            ru) printf "готово" ;;
            *)  printf "done" ;;
            esac ;;
        killing_main_pid) case "$UI_LANG" in
            ru) printf '%s' "  Останавливаем основной процесс %s... " ;;
            *)  printf '%s' "  Killing main PID %s... " ;;
            esac ;;
        killing_remaining_procs) case "$UI_LANG" in
            ru) printf '%s' "  Останавливаем оставшиеся процессы '%s'... " ;;
            *)  printf '%s' "  Killing remaining '%s' processes... " ;;
            esac ;;

        retry_opkg_update_hint) case "$UI_LANG" in
            ru) printf "Если установка зависимостей ниже не удастся, выполните 'opkg update' вручную и повторите." ;;
            *)  printf "If dependency install fails below, run 'opkg update' manually and retry." ;;
            esac ;;
        pkg_already_installed) case "$UI_LANG" in
            ru) printf '%s' "%s — уже установлен" ;;
            *)  printf '%s' "%s — already installed" ;;
            esac ;;
        installing_pkg) case "$UI_LANG" in
            ru) printf '%s' "  Устанавливаем %s... " ;;
            *)  printf '%s' "  Installing %s... " ;;
            esac ;;
        unattended_uninstall_complete) case "$UI_LANG" in
            ru) printf "Удаление завершено (podkop и sing-box не затронуты)." ;;
            *)  printf "Uninstall complete (podkop and sing-box untouched)." ;;
            esac ;;

        config_written) case "$UI_LANG" in
            ru) printf '%s' "Конфиг записан в /etc/config/%s" ;;
            *)  printf '%s' "Config written to /etc/config/%s" ;;
            esac ;;
        uci_summary_title) case "$UI_LANG" in
            ru) printf "  Сводка UCI-конфига:" ;;
            *)  printf "  UCI config summary:" ;;
            esac ;;
        ask_setup_autostart) case "$UI_LANG" in
            ru) printf "Настроить автозапуск через init.d? (Y/n): " ;;
            *)  printf "Set up autostart via init.d? (Y/n): " ;;
            esac ;;
        downloading_initd) case "$UI_LANG" in
            ru) printf "  Скачиваем init.d-скрипт... " ;;
            *)  printf "  Downloading init.d script... " ;;
            esac ;;
        initd_not_available) case "$UI_LANG" in
            ru) printf "недоступен — генерируем локально" ;;
            *)  printf "not available — generating locally" ;;
            esac ;;
        generated_init_script) case "$UI_LANG" in
            ru) printf "Сгенерирован минимальный procd init-скрипт." ;;
            *)  printf "Generated minimal procd init script." ;;
            esac ;;
        autostart_enabled) case "$UI_LANG" in
            ru) printf '%s' "Автозапуск включён: %s" ;;
            *)  printf '%s' "Autostart enabled: %s" ;;
            esac ;;
        autostart_skipped) case "$UI_LANG" in
            ru) printf '%s' "Автозапуск пропущен. Запустите вручную: %s &" ;;
            *)  printf '%s' "Autostart skipped. Start manually: %s &" ;;
            esac ;;
        ask_start_now) case "$UI_LANG" in
            ru) printf "Запустить бота сейчас? (Y/n): " ;;
            *)  printf "Start the bot now? (Y/n): " ;;
            esac ;;
        starting_via_initd) case "$UI_LANG" in
            ru) printf "  Запускаем через init.d... " ;;
            *)  printf "  Starting via init.d... " ;;
            esac ;;
        bot_started_initd) case "$UI_LANG" in
            ru) printf "Бот запущен через init.d." ;;
            *)  printf "Bot started via init.d." ;;
            esac ;;
        unknown_fallback_direct) case "$UI_LANG" in
            ru) printf "неизвестно — переходим на прямой запуск" ;;
            *)  printf "UNKNOWN — falling back to direct start" ;;
            esac ;;
        bot_started_directly) case "$UI_LANG" in
            ru) printf '%s' "Бот запущен напрямую (PID: %s)." ;;
            *)  printf '%s' "Bot started directly (PID: %s)." ;;
            esac ;;
        bot_started) case "$UI_LANG" in
            ru) printf '%s' "Бот запущен (PID: %s)." ;;
            *)  printf '%s' "Bot started (PID: %s)." ;;
            esac ;;
        bot_not_started) case "$UI_LANG" in
            ru) printf "Бот не запущен. Запустите когда будете готовы:" ;;
            *)  printf "Bot not started. Run when ready:" ;;
            esac ;;
        or_manually) case "$UI_LANG" in
            ru) printf '%s' "  # или: %s &" ;;
            *)  printf '%s' "  # or: %s &" ;;
            esac ;;
        skipping_invalid_admin) case "$UI_LANG" in
            ru) printf '%s' "Пропущен некорректный admin ID (не число): %s" ;;
            *)  printf '%s' "Skipping invalid admin ID (not numeric): %s" ;;
            esac ;;

        *) printf '%s' "$1" ;;  # fallback: unknown key, print key itself (helps catch typos)
    esac
}

# ── Variant detection ──────────────────────────────────────────────────────────
# PODKOP_VARIANT one of: original | evolution | netshift | plus | none
# Detection strategy, in order of confidence:
#   1. Package name via opkg/apk (podkop-plus, podkop, etc. — name varies by
#      maintainer/fork but is the strongest signal when present).
#   2. UCI field fingerprint: Plus uses `action=` on routing sections and has
#      Plus-only fields (subscription_urls, rule_set, detect_server_country).
#      Original/evolution/netshift use the legacy `connection_type=` field.
#      Evolution and netshift are functionally close to original for our
#      purposes (same connection_type schema) — distinguished only by binary
#      path/package name when available, otherwise both fold into a single
#      "legacy schema" bucket reported as best-guess.
#   3. Fallback: "none" if podkop is not installed at all.
detect_podkop_variant() {
    local _bin_path=""
    # forkop = renamed/migrated Podkop Plus (package/service/UCI: podkop-plus -> forkop).
    # MUST be checked BEFORE plus: a migrated box may still have stale podkop-plus
    # files, but if forkop is present the system is Forkop.
    if [ -f "/usr/bin/forkop" ] || [ -f "/etc/init.d/forkop" ] || [ -f "/etc/config/forkop" ]; then
        printf 'forkop'
        return
    fi
    # Binary-signal first: plus and netshift have their own binaries. Check them
    # before anything else so they're detected even before package metadata.
    if [ -f "/usr/bin/podkop-plus" ]; then
        printf 'plus'
        return
    fi
    # netshift = renamed podkop-evolution: binary /usr/bin/netshift, UCI namespace
    # "netshift", package "netshift". Must be checked explicitly — it shares none
    # of podkop's paths/namespaces, so without this it reads as "none".
    if [ -f "/usr/bin/netshift" ] || uci -q get netshift.settings >/dev/null 2>&1; then
        printf 'netshift'
        return
    fi
    [ -f "/usr/bin/podkop" ] && _bin_path="/usr/bin/podkop"
    [ -z "$_bin_path" ] && [ -f "/usr/sbin/podkop" ] && _bin_path="/usr/sbin/podkop"

    if [ -z "$_bin_path" ] && ! uci -q get podkop.settings >/dev/null 2>&1 \
                            && ! uci -q get forkop.settings >/dev/null 2>&1 \
                            && ! uci -q get podkop-plus.settings >/dev/null 2>&1 \
                            && ! uci -q get netshift.settings >/dev/null 2>&1; then
        printf 'none'
        return
    fi

    # Package-name signal (works when opkg/apk metadata is present)
    local _pkg_name=""
    case "$PKG_MANAGER" in
        apk)
            apk info 2>/dev/null | grep -qE '^forkop$'  && _pkg_name="forkop"
            [ -z "$_pkg_name" ] && apk info 2>/dev/null | grep -qE '^podkop-plus$'  && _pkg_name="plus"
            [ -z "$_pkg_name" ] && apk info 2>/dev/null | grep -qE '^podkop-evolution$' && _pkg_name="evolution"
            [ -z "$_pkg_name" ] && apk info 2>/dev/null | grep -qE '^netshift$'  && _pkg_name="netshift"
            ;;
        opkg)
            opkg list-installed 2>/dev/null | grep -qE '^forkop '  && _pkg_name="forkop"
            [ -z "$_pkg_name" ] && opkg list-installed 2>/dev/null | grep -qE '^podkop-plus '  && _pkg_name="plus"
            [ -z "$_pkg_name" ] && opkg list-installed 2>/dev/null | grep -qE '^podkop-evolution ' && _pkg_name="evolution"
            [ -z "$_pkg_name" ] && opkg list-installed 2>/dev/null | grep -qE '^netshift '  && _pkg_name="netshift"
            ;;
    esac
    if [ -n "$_pkg_name" ]; then
        printf '%s' "$_pkg_name"
        return
    fi

    # UCI fingerprint: forkop uses its own namespace with action= sections.
    if uci -q show forkop 2>/dev/null | grep -qE '^forkop\.[^.]+\.action='; then
        printf 'forkop'
        return
    fi
    # UCI fingerprint: does any podkop-plus.* section exist with action=proxy?
    if uci -q show podkop-plus 2>/dev/null | grep -qE '^podkop-plus\.[^.]+\.action='; then
        printf 'plus'
        return
    fi
    # Plus-only field check on the legacy "podkop" package name, in case the
    # Plus fork was installed under the original UCI package name.
    if uci -q show podkop 2>/dev/null | grep -qE '\.(subscription_urls|rule_set|rule_set_with_subnets|detect_server_country)='; then
        printf 'plus'
        return
    fi

    # Legacy connection_type schema present → original/evolution/netshift.
    # We cannot reliably tell these three apart without a package-name match,
    # so report "original" as the safe functional default (UCI schema and
    # mixed_proxy fields are identical across all three for our purposes).
    if uci -q show podkop 2>/dev/null | grep -qE '\.connection_type='; then
        printf 'original'
        return
    fi

    # A podkop binary or podkop.* UCI exists but matched no fingerprint above —
    # this is an original Podkop whose schema we don't specifically recognise
    # (e.g. an old 0.4.x release predating connection_type). Treat it as original
    # (safe default: same UCI package "podkop", same mixed_proxy fields) rather
    # than "unknown", which breaks repo/version resolution downstream.
    if [ -n "$_bin_path" ] || uci -q get podkop.settings >/dev/null 2>&1 \
                           || uci -q show podkop >/dev/null 2>&1; then
        printf 'original'
        return
    fi

    printf 'unknown'
}

variant_label() {
    case "$1" in
        original)  msg variant_label_original ;;
        evolution) msg variant_label_evolution ;;
        netshift)  msg variant_label_netshift ;;
        plus)      msg variant_label_plus ;;
        forkop)    printf 'Forkop' ;;
        *)         msg variant_label_unknown ;;
    esac
}

# ── UCI package name for the detected variant ──────────────────────────────────
# Plus uses its own UCI package "podkop-plus"; everything else uses "podkop".
_podkop_uci_pkg() {
    case "$PODKOP_VARIANT" in
        forkop)   printf 'forkop' ;;
        plus)     printf 'podkop-plus' ;;
        netshift) printf 'netshift' ;;
        *)        printf 'podkop' ;;
    esac
}
# _vendor_fallback: last-resort offline source. Given the same url/dest as
# download_file(), copies a vendored copy from $VENDOR_DIR matched by URL
# basename (podkop_bot.sh→podkop_bot, podkop_bot_init→podkop_bot_init).
# Returns 0 if copied, 1 if no vendored copy applies.
_vendor_fallback() {
    local url="$1" dest="$2"
    local _base _src
    _base=$(basename "$url")
    case "$_base" in
        podkop_bot.sh)   _src="$VENDOR_DIR/podkop_bot" ;;
        podkop_bot_init) _src="$VENDOR_DIR/podkop_bot_init" ;;
        *) return 1 ;;
    esac
    [ -f "$_src" ] || return 1
    cp "$_src" "$dest" 2>/dev/null || return 1
    [ -s "$dest" ] || return 1
    printf "$(msg dl_used_vendor)" "$_src" 2>/dev/null || printf "    -> using bundled offline copy: %s\n" "$_src"
    return 0
}

download_file() {
    local url="$1" dest="$2"
    # Try direct (wget, then curl), then SOCKS fallover.
    # BusyBox wget hangs indefinitely without -T on slow/broken WAN.
    wget -q -T 15 -O "$dest" "$url" 2>/dev/null && return 0
    curl -fsSL --connect-timeout 10 --max-time 30 -o "$dest" "$url" 2>/dev/null && return 0

    # Direct failed — GitHub/Telegram may be blocked by ISP.
    printf "$(msg dl_direct_failed)"

    local _socks_list; _socks_list=$(_get_socks_endpoints)
    if [ -z "$_socks_list" ]; then
        _vendor_fallback "$url" "$dest" && return 0
        printf "$(msg dl_no_socks_configured)"
        printf "$(msg dl_fix_mixed_proxy1)"
        printf "$(msg dl_fix_mixed_proxy2)"
        die "Failed to download $url — direct blocked, no SOCKS available, no offline copy." 15
    fi

    printf "$(msg dl_trying_socks)"
    local _ep
    for _ep in $_socks_list; do
        printf "    → %s ... " "$_ep"
        if curl -fsSL --connect-timeout 6 --max-time 30 -x "$_ep" -o "$dest" "$url" 2>/dev/null; then
            printf "OK\n"
            return 0
        fi
        printf "$(msg dl_failed_word)"
    done

    _vendor_fallback "$url" "$dest" && return 0

    printf "$(msg dl_all_socks_failed)"
    printf "$(msg dl_check_podkop_running)"
    printf "    uci show %s | grep mixed_proxy\n" "$(_podkop_uci_pkg)"
    printf "$(msg dl_or_add_fallback)"
    die "Failed to download $url — no working transport (direct, SOCKS, or offline copy)." 15
}

# download_file_optional: NON-FATAL download for optional assets (e.g. init.d
# script). Same transport tiers as download_file but returns 1 on failure
# instead of die(), so callers can fall back to a locally-generated/unchanged
# asset. NEVER use download_file (fatal) for optional assets — on a network
# failure it kills the script, and in update flow the bot binary is already
# replaced, leaving no path to restart/rollback.
download_file_optional() {
    local url="$1" dest="$2"
    wget -q -T 15 -O "$dest" "$url" 2>/dev/null && return 0
    curl -fsSL --connect-timeout 10 --max-time 30 -o "$dest" "$url" 2>/dev/null && return 0

    local _ep
    for _ep in $(_get_socks_endpoints); do
        curl -fsSL --connect-timeout 6 --max-time 30 -x "$_ep" -o "$dest" "$url" 2>/dev/null && return 0
    done

    _vendor_fallback "$url" "$dest" && return 0

    rm -f "$dest"
    return 1
}

uci_get() { uci -q get "${UCI_PKG}.${UCI_SEC}.${1}" 2>/dev/null; }

# _bot_alive: 0 (true) if a live /usr/bin/podkop_bot process exists. Same /proc
# scan as _reap_bot_forks (minus the killing) — used to verify a (re)start
# actually produced a running bot, instead of trusting `init status` which lies
# on legacy init scripts.
_bot_alive() {
    local _p _cl
    for _p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
        [ "$_p" = "$$" ] && continue
        _cl=$( (tr '\0' ' ' < "/proc/$_p/cmdline") 2>/dev/null ) || continue
        case "$_cl" in
            *"/etc/init.d/podkop_bot"*) continue ;;
            *rc.common*) continue ;;
            *"/usr/bin/podkop_bot"*) return 0 ;;
        esac
    done
    return 1
}

# _reap_bot_forks: kill every live `/usr/bin/podkop_bot` process via a /proc
# scan, escalating to kill -9, then clear the pidfile. Legacy init scripts
# (bot <=0.15.1) had no stop_service and no fork cleanup, so `init stop` left
# forked children alive; repeated updates/respawns accumulated zombie instances
# (observed up to 6) that fought over the Telegram API (409 Conflict / getUpdates
# race). This reaps them deterministically, independent of the installed init.
# SYNC: mirrors _kill_all_podkop_bot() in the generated init.d (search that
# name); keep both in step if the match/exclude logic changes.
_reap_bot_forks() {
    local _pids="" _p _cl
    for _p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
        [ "$_p" = "$$" ] && continue
        _cl=$( (tr '\0' ' ' < "/proc/$_p/cmdline") 2>/dev/null ) || continue
        case "$_cl" in
            *"/etc/init.d/podkop_bot"*) continue ;;
            *rc.common*) continue ;;
            *"/usr/bin/podkop_bot"*) _pids="$_pids $_p" ;;
        esac
    done
    [ -z "$_pids" ] && { rm -f /tmp/podkop_bot/podkop_bot.pid 2>/dev/null; return 0; }
    kill $_pids 2>/dev/null
    local _i=0
    while [ "$_i" -lt 8 ]; do
        local _alive=""
        for _p in $_pids; do [ -d "/proc/$_p" ] && _alive="$_alive $_p"; done
        [ -z "$_alive" ] && break
        sleep 1; _i=$((_i + 1))
    done
    for _p in $_pids; do [ -d "/proc/$_p" ] && kill -9 "$_p" 2>/dev/null; done
    rm -f /tmp/podkop_bot/podkop_bot.pid 2>/dev/null
    return 0
}

# _init_is_legacy: returns 0 (true) if the installed init.d is a legacy script
# that lacks fork cleanup. Marker: a working init carries the _kill_all_podkop_bot
# function; legacy ones (no stop_service, procd-only) do not. A missing file is
# also treated as "needs the working init".
_init_is_legacy() {
    [ -f "$INIT_PATH" ] || return 0
    grep -q '_kill_all_podkop_bot' "$INIT_PATH" 2>/dev/null && return 1
    return 0
}

# _write_working_init: write the canonical procd init.d to $INIT_PATH. Single
# source of the init body — both first-install and update call this, so the
# generated init never drifts between flows. The bot FORKS a health daemon +
# startup-notify child; procd supervises only the main PID, so a plain stop
# leaves children alive → multiple getUpdates pollers on one token → Telegram
# 409 + zombie accumulation. Hence the explicit _kill_all_podkop_bot in both
# start_service and stop_service.
# SYNC: _kill_all_podkop_bot here mirrors _reap_bot_forks() above; keep in step.
_write_working_init() {
    cat > "$INIT_PATH" << 'INITEOF'
#!/bin/sh /etc/rc.common
# podkop_bot init.d — fixed to reliably stop a FORKING bot.
#
# The bot forks a health daemon + startup-notify child that keep their own
# getUpdates poll. procd supervises only the main PID, so a plain procd stop
# leaves those children alive → two getUpdates pollers on one token → Telegram
# 409 Conflict, flapping routes, duplicated processes after every restart.
#
# Fix: an explicit stop_service that kills ALL podkop_bot processes (main +
# forked children), plus a clean start that waits for the old ones to die.

START=99
STOP=10
USE_PROCD=1
PROG=/usr/bin/podkop_bot

# Kill every running podkop_bot process (main + forked daemons).
# Matches the interpreter line "/bin/sh /usr/bin/podkop_bot" — busybox shows the
# process as {podkop_bot}, so killall by name does NOT work; we match cmdline.
_kill_all_podkop_bot() {
    local _pids _p
    # Collect PIDs whose /proc/<pid>/cmdline contains the bot path, excluding self.
    _pids=""
    for _p in $(ls /proc 2>/dev/null | grep -E '^[0-9]+$'); do
        [ "$_p" = "$$" ] && continue
        if grep -qa 'podkop_bot' "/proc/$_p/cmdline" 2>/dev/null; then
            # skip this init script itself (cmdline contains rc.common/init path)
            grep -qa '/etc/init.d/podkop_bot\|rc.common' "/proc/$_p/cmdline" 2>/dev/null && continue
            grep -qa '/usr/bin/podkop_bot' "/proc/$_p/cmdline" 2>/dev/null && _pids="$_pids $_p"
        fi
    done

    [ -z "$_pids" ] && return 0

    # Graceful TERM first
    kill $_pids 2>/dev/null
    # Wait up to 8s for them to exit
    local _i=0
    while [ "$_i" -lt 8 ]; do
        local _alive=""
        for _p in $_pids; do
            [ -d "/proc/$_p" ] && _alive="$_alive $_p"
        done
        [ -z "$_alive" ] && break
        sleep 1; _i=$((_i + 1))
    done

    # Force-kill any survivors
    for _p in $_pids; do
        [ -d "/proc/$_p" ] && kill -9 "$_p" 2>/dev/null
    done

    # Drop both PID files so the next start isn't blocked:
    # podkop_bot.pid = single-instance lock (written by bot at startup)
    # bot.pid        = main PID used by safe_stop_bot in the installer
    rm -f /tmp/podkop_bot/podkop_bot.pid /tmp/podkop_bot/bot.pid 2>/dev/null
}

start_service() {
    # If a healthy bot instance is already running under the lock file,
    # skip the kill — avoid disrupting a running bot on redundant "start".
    # Otherwise kill stale processes and clean the lock before starting fresh.
    local _lock_pid
    _lock_pid=$(cat /tmp/podkop_bot/podkop_bot.pid 2>/dev/null)
    if [ -n "$_lock_pid" ] && [ -d "/proc/$_lock_pid" ] &&        grep -qa '/usr/bin/podkop_bot' "/proc/$_lock_pid/cmdline" 2>/dev/null; then
        return 0  # healthy instance running — do not disturb it
    else
        _kill_all_podkop_bot
        sleep 1
        rm -f /tmp/podkop_bot/podkop_bot.pid 2>/dev/null
    fi

    procd_open_instance
    procd_set_param command "$PROG"
    # respawn: 3600s window, max 5 crashes, 10s delay.
    procd_set_param respawn 3600 5 10
    procd_set_param stdout 0
    procd_set_param stderr 0
    procd_close_instance
}

stop_service() {
    # procd will signal the supervised main PID, but we must also reap the
    # forked health/poll children that procd does not track.
    _kill_all_podkop_bot
}

reload_service() {
    stop
    start
}
INITEOF
    chmod +x "$INIT_PATH"
}


# _get_socks_endpoints: read tier1 (podkop mixed_proxy) and fallback_socks from
# UCI for use before the bot starts. Outputs space-separated "socks5h://IP:PORT"
# entries (tier1 first, then fallbacks).
#
# Tier1 detection differs by variant because the routing-section schema
# differs:
#   - original / evolution / netshift: `connection_type=proxy` +
#     `mixed_proxy_enabled=1` on a section of UCI package "podkop".
#   - plus: `action=proxy` + `mixed_proxy_enabled=1` on a section of UCI
#     package "podkop-plus". (Plus renamed connection_type → action and
#     moved everything to its own UCI package — see podkop-plus source,
#     luci-app-podkop-plus/.../section.js ROUTING_SECTION_ACTIONS.)
# Before this fix, only the connection_type schema was checked, so tier1
# was always empty on any Plus install — first-time installs on Plus had
# zero fallback transport if GitHub was blocked (fallback_socks doesn't
# exist yet on a fresh install either).
_get_socks_endpoints() {
    local _results=""
    local _pkg; _pkg=$(_podkop_uci_pkg)
    local _primary_sec _port _lan_ip _field_name

    if [ "$_pkg" = "podkop-plus" ] || [ "$_pkg" = "forkop" ]; then
        _field_name="action"
    else
        _field_name="connection_type"
    fi

    _primary_sec=$(uci -q show "$_pkg" 2>/dev/null \
        | grep -E "^${_pkg}\.[^.=]+=section$" \
        | while IFS='=' read -r _k _v; do
            _s=$(printf '%s' "$_k" | cut -d. -f2)
            _ct=$(uci -q get "${_pkg}.${_s}.${_field_name}" 2>/dev/null)
            _me=$(uci -q get "${_pkg}.${_s}.mixed_proxy_enabled" 2>/dev/null)
            { [ "$_ct" = "proxy" ] || [ "$_ct" = "connection" ]; } && [ "$_me" = "1" ] && echo "$_s" && break
        done | head -1)

    # Fallback: if no variant-specific match, also try the OTHER field name
    # in case detection picked the wrong package/variant (defensive — cheap
    # to check both, and this runs only a handful of times per install).
    if [ -z "$_primary_sec" ]; then
        local _other_field
        [ "$_field_name" = "action" ] && _other_field="connection_type" || _other_field="action"
        _primary_sec=$(uci -q show "$_pkg" 2>/dev/null \
            | grep -E "^${_pkg}\.[^.=]+=section$" \
            | while IFS='=' read -r _k _v; do
                _s=$(printf '%s' "$_k" | cut -d. -f2)
                _ct=$(uci -q get "${_pkg}.${_s}.${_other_field}" 2>/dev/null)
                _me=$(uci -q get "${_pkg}.${_s}.mixed_proxy_enabled" 2>/dev/null)
                { [ "$_ct" = "proxy" ] || [ "$_ct" = "connection" ]; } && [ "$_me" = "1" ] && echo "$_s" && break
            done | head -1)
    fi

    if [ -n "$_primary_sec" ]; then
        _port=$(uci -q get "${_pkg}.${_primary_sec}.mixed_proxy_port" 2>/dev/null || echo "2080")
        # Resolve the actual listen address from sing-box's own config.json
        # (matches by listen_port) instead of trusting raw network.lan.ipaddr.
        # sing-box can be configured to listen on a different address via
        # service_listen_address — using the UCI LAN IP blindly can point
        # the SOCKS fallback at an address nothing is actually listening on.
        # Falls back to network.lan.ipaddr (then a hardcoded default) if the
        # config file is missing, unreadable, or jq isn't available yet.
        _lan_ip=""
        if [ -f /etc/sing-box/config.json ] && command -v jq >/dev/null 2>&1; then
            _lan_ip=$(jq -r --argjson p "${_port:-0}" \
                '.inbounds[]? | select(.listen_port == $p) | .listen // empty' \
                /etc/sing-box/config.json 2>/dev/null | head -1)
            # listen="0.0.0.0" or "::" means "all interfaces" — not a usable
            # target address for a SOCKS client, fall back to LAN IP.
            case "$_lan_ip" in
                ""|0.0.0.0|::|"[::]") _lan_ip="" ;;
            esac
        fi
        [ -z "$_lan_ip" ] && _lan_ip=$(uci -q get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
        _results="socks5h://${_lan_ip}:${_port}"
    fi

    # fallback_socks from bot UCI config (only meaningful on update — a
    # fresh install has no podkop_bot UCI config yet).
    # NOTE: deliberately NOT using eval here. uci show emits one line per
    # list entry (pkg.sec.field='value'); we strip the surrounding quotes
    # with sed and re-validate with validate_socks_url so a malformed or
    # hand-edited UCI value is skipped rather than passed through verbatim.
    local _fb_line _fb
    while IFS= read -r _fb_line; do
        [ -z "$_fb_line" ] && continue
        _fb=$(printf '%s' "$_fb_line" | cut -d= -f2- | sed "s/^'//; s/'$//")
        if validate_socks_url "$_fb"; then
            _results="${_results:+$_results }${_fb}"
        fi
    done <<FBEOF
$(uci -q show podkop_bot.settings.fallback_socks 2>/dev/null)
FBEOF
    printf '%s' "$_results"
}

# _curl_socks_fallover: curl with automatic SOCKS fallover.
# Tries direct first, then each SOCKS endpoint from _get_socks_endpoints.
# $1=max_time, remaining args passed to curl.
# On success sets _last_socks_route="" (direct) or "socks5h://..." (proxy used).
_curl_socks_fallover() {
    local _max="${1:-15}"; shift
    local _ct=6
    _last_socks_route=""
    # -L is required: GitHub release-asset URLs 302-redirect to
    # objects.githubusercontent.com; without following the redirect the body is
    # empty (0-byte download). Harmless for non-redirecting URLs (API/raw).
    # 1. Direct
    if curl -fsSL --connect-timeout "$_ct" --max-time "$_max" "$@" 2>/dev/null; then
        return 0
    fi
    # 2. SOCKS tiers
    local _ep
    for _ep in $(_get_socks_endpoints); do
        if curl -fsSL --connect-timeout "$_ct" --max-time "$_max" -x "$_ep" "$@" 2>/dev/null; then
            _last_socks_route="$_ep"
            return 0
        fi
    done
    return 1
}

# ── LuCI web UI (luci-app-podkop-bot) install/update ────────────────────────
# The web UI is a SEPARATE package from the bot. This installs or updates it by
# fetching the latest release asset from GitHub and handing it to the system
# package manager. Two things make it non-trivial:
#   1. The asset kind depends on the package manager: opkg wants the .ipk,
#      apk (OpenWrt 24+/25+) wants the .apk.
#   2. The web UI ships the rpcd backend that may itself be driving this very
#      update. So the actual package-manager call is DETACHED (setsid/nohup) and
#      logs to a file the UI polls — if rpcd restarts mid-install, the install
#      still completes and the log survives.
LUCI_REPO="Medvedolog/luci-app-podkop-bot"
LUCI_UPDATE_LOG="/tmp/podkop_bot_luci_update.log"

# _update_luci_app: fetch latest LuCI release asset and install it detached.
# Honors the same direct→SOCKS fallover as everything else. Writes progress to
# LUCI_UPDATE_LOG. Returns 0 once the install has been *launched* (not finished
# — it's detached on purpose); non-zero if we couldn't even fetch the asset.
_update_luci_app() {
    : > "$LUCI_UPDATE_LOG" 2>/dev/null
    _lu_log() { echo "$1" | tee -a "$LUCI_UPDATE_LOG" 2>/dev/null; }

    # This path needs curl (via _curl_socks_fallover). On a router with the bot
    # already installed, curl is always present. Only a manual --action
    # update-luci on a bare system could hit this — fail loudly, don't hang.
    if ! command -v curl >/dev/null 2>&1; then
        _lu_log "[!!] curl not found. Install the bot first (it pulls curl), or install curl manually."
        return 1
    fi

    # pkg manager → asset suffix
    local _pm=""
    if command -v apk >/dev/null 2>&1; then _pm="apk"
    elif command -v opkg >/dev/null 2>&1; then _pm="opkg"
    else _lu_log "[!!] Neither apk nor opkg found"; return 1; fi
    local _suffix; [ "$_pm" = "apk" ] && _suffix="_noarch.apk" || _suffix="_all.ipk"
    _lu_log "[OK] Package manager: $_pm (asset *$_suffix)"

    # latest release metadata
    local _api="https://api.github.com/repos/${LUCI_REPO}/releases/latest"
    _lu_log "  Fetching latest release info…"
    local _json; _json=$(_curl_socks_fallover 15 "$_api")
    if [ -z "$_json" ]; then _lu_log "[!!] Could not reach GitHub API (direct or SOCKS)"; return 1; fi
    [ -n "$_last_socks_route" ] && _lu_log "  (via $_last_socks_route)" || _lu_log "  (direct)"

    local _tag; _tag=$(printf '%s' "$_json" | sed -n 's/.*"tag_name"[: ]*"\([^"]*\)".*/\1/p' | head -1)
    [ -n "$_tag" ] && _lu_log "[OK] Latest release: $_tag"

    # asset download URL matching our suffix
    local _url
    _url=$(printf '%s' "$_json" \
        | tr ',' '\n' \
        | grep -oE '"browser_download_url"[: ]*"[^"]*'"$_suffix"'"' \
        | sed -n 's/.*"\(https[^"]*\)".*/\1/p' | head -1)
    if [ -z "$_url" ]; then _lu_log "[!!] No $_suffix asset in latest release"; return 1; fi
    _lu_log "  Asset: $_url"

    # download to /tmp
    local _dst="/tmp/luci-app-podkop-bot${_suffix}"
    rm -f "$_dst" 2>/dev/null
    _lu_log "  Downloading…"
    if ! _curl_socks_fallover 60 -o "$_dst" "$_url"; then
        _lu_log "[!!] Download failed"; return 1
    fi
    [ -s "$_dst" ] || { _lu_log "[!!] Downloaded file is empty"; return 1; }
    _lu_log "[OK] Downloaded $(wc -c < "$_dst" 2>/dev/null) bytes → $_dst"

    # build the detached install command per package manager
    local _cmd
    if [ "$_pm" = "apk" ]; then
        _cmd="apk add --allow-untrusted '$_dst'"
    else
        _cmd="opkg install --force-reinstall '$_dst'"
    fi

    _lu_log "  Installing via $_pm (detached — the web UI may restart)…"
    # Detach so a mid-install rpcd restart doesn't kill the package manager.
    # setsid if available, else nohup+&; append to the same log.
    if command -v setsid >/dev/null 2>&1; then
        setsid sh -c "{ $_cmd; echo \"[done] exit \$?\"; } >> '$LUCI_UPDATE_LOG' 2>&1" >/dev/null 2>&1 &
    else
        nohup sh -c "{ $_cmd; echo \"[done] exit \$?\"; } >> '$LUCI_UPDATE_LOG' 2>&1" >/dev/null 2>&1 &
    fi
    _lu_log "  Launched. Watch this log for completion."
    return 0
}
# On a brand-new install there is no podkop Mixed Proxy guaranteed to be
# enabled yet and no podkop_bot fallback_socks (that config doesn't exist
# until this installer writes it at the end). If GitHub/raw.githubusercontent
# is blocked and tier1 isn't available either, the installer would otherwise
# have zero transport for both package manager updates (apk/opkg) and the
# bot script download. This lets the user paste in a proxy they already have
# (VPS, another router, a SOCKS/HTTP proxy on the LAN) and applies it
# TEMPORARILY — for the lifetime of this script's process only — to curl,
# wget, apk and opkg via standard proxy environment variables. Nothing is
# written to UCI or to any persistent system file; _teardown_user_proxy()
# unsets everything before the script exits (normal exit, die(), or trap).
# (_PROXY_BOOTSTRAPPED is initialized earlier, near LOCK_DIR, before trap is set.)

# _probe_github_reachable: quick check whether raw.githubusercontent.com is
# reachable directly, without involving any proxy. Used to decide whether to
# even bother asking the user for a proxy. Tries curl first, falls back to
# wget — on a truly clean router curl/jq aren't installed yet (that's the
# whole point of this bootstrap), but BusyBox wget is always present.
_probe_github_reachable() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsS --connect-timeout 6 --max-time 10 -o /dev/null \
            "https://raw.githubusercontent.com/Medvedolog/podkop_bot/main/version.txt" 2>/dev/null
        return $?
    fi
    wget -q -T 10 -O /dev/null \
        "https://raw.githubusercontent.com/Medvedolog/podkop_bot/main/version.txt" 2>/dev/null
}

# _apply_user_proxy: export standard proxy env vars (used by curl, wget, and
# both apk and opkg, which all respect http_proxy/https_proxy/all_proxy) plus
# opkg's own option, for the remainder of this process.
# $1 = proxy URL, any of: http://host:port, https://host:port,
#      socks5://host:port, socks5h://host:port
_apply_user_proxy() {
    local _purl="$1"
    export http_proxy="$_purl"
    export https_proxy="$_purl"
    export HTTP_PROXY="$_purl"
    export HTTPS_PROXY="$_purl"
    # curl honors all_proxy for non-http(s) schemes (socks5/socks5h) too.
    export all_proxy="$_purl"
    export ALL_PROXY="$_purl"
    # opkg reads http_proxy/https_proxy from the environment already, but on
    # some builds also needs no_proxy set (even empty) to avoid bypassing it
    # for "local" hostnames it misdetects.
    export no_proxy="${no_proxy:-}"
    _PROXY_BOOTSTRAPPED=1
}

# _teardown_user_proxy: unset everything _apply_user_proxy set. Safe to call
# even if no proxy was ever applied (checks _PROXY_BOOTSTRAPPED first).
_teardown_user_proxy() {
    [ "$_PROXY_BOOTSTRAPPED" = "1" ] || return 0
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY no_proxy 2>/dev/null || true
    _PROXY_BOOTSTRAPPED=0
}

# _validate_proxy_url: accept http://, https://, socks5:// or socks5h:// with
# a host and numeric port 1-65535. Re-uses the same port-range check as
# validate_socks_url but allows the http(s) schemes too.
_validate_proxy_url() {
    local _u="$1"
    echo "$_u" | grep -qE '^(https?|socks5h?)://[^:/]+:[0-9]{1,5}$' || return 1
    local _p; _p=$(echo "$_u" | sed 's|.*:||')
    awk -v p="$_p" 'BEGIN { exit (p >= 1 && p <= 65535) ? 0 : 1 }'
}

# _maybe_ask_user_proxy: only called on a fresh install (no existing
# podkop_bot config), and only if GitHub is unreachable AND no podkop tier1
# is available — i.e. exactly the case where the installer would otherwise
# have no transport at all. Skipped entirely in unattended mode (no TTY to
# prompt); unattended callers should pass a working network or pre-populate
# fallback_socks via config for the *post-install* bot to use — this bootstrap
# proxy only affects the installer's own process, never gets persisted, and
# unattended runs have no human to confirm a pasted-in proxy is trustworthy.
_maybe_ask_user_proxy() {
    [ "$UNATTENDED" = "1" ] && return 0
    _probe_github_reachable && return 0
    [ -n "$(_get_socks_endpoints)" ] && return 0

    echo ""
    if [ "$UI_LANG" = "ru" ]; then
        warn "GitHub недоступен напрямую, и резервный SOCKS через podkop не найден."
        echo "  Установщику нужна сеть, чтобы скачать зависимости (curl, jq) и сам бот."
        echo ""
        echo "  Если у вас есть прокси (VPS, другой роутер, SOCKS/HTTP-прокси в сети),"
        echo "  можно временно использовать его ТОЛЬКО для этого запуска установщика —"
        echo "  ничего не будет сохранено в систему или в /etc/config."
        echo ""
        echo "  Форматы: http://ХОСТ:ПОРТ, https://ХОСТ:ПОРТ,"
        echo "           socks5://ХОСТ:ПОРТ, socks5h://ХОСТ:ПОРТ"
        if ! command -v curl >/dev/null 2>&1; then
            echo ""
            echo "  Внимание: curl ещё не установлен, проверка прокси пойдёт через wget,"
            echo "  который умеет только http(s)-прокси. Если введёте socks5/socks5h —"
            echo "  проверка может ошибочно показать FAILED, хотя прокси рабочий; после"
            echo "  установки curl ниже SOCKS-прокси заработает корректно."
        fi
        echo ""
        printf "  Указать прокси для этой установки? (y/N): "
    else
        warn "GitHub is not reachable directly, and no podkop SOCKS fallback was found."
        echo "  The installer needs network access to fetch dependencies (curl, jq)"
        echo "  and the bot script itself."
        echo ""
        echo "  If you have a proxy available (a VPS, another router, a SOCKS/HTTP"
        echo "  proxy on your LAN), you can use it TEMPORARILY for this installer run"
        echo "  only — nothing is saved to the system or to /etc/config."
        echo ""
        echo "  Formats: http://HOST:PORT, https://HOST:PORT,"
        echo "           socks5://HOST:PORT, socks5h://HOST:PORT"
        if ! command -v curl >/dev/null 2>&1; then
            echo ""
            echo "  Note: curl isn't installed yet, so the test below uses wget, which"
            echo "  only supports http(s) proxies. If you enter a socks5/socks5h proxy,"
            echo "  the test may show FAILED even though the proxy works fine — it will"
            echo "  work correctly once curl is installed in the next step."
        fi
        echo ""
        printf "  Provide a proxy for this install? (y/N): "
    fi
    read -r _ask_proxy
    [ "$_ask_proxy" != "y" ] && [ "$_ask_proxy" != "Y" ] && return 0

    local _attempts=0
    while [ "$_attempts" -lt 3 ]; do
        if [ "$UI_LANG" = "ru" ]; then
            printf "  Прокси (например socks5h://10.0.0.5:1080): "
        else
            printf "  Proxy (e.g. socks5h://10.0.0.5:1080): "
        fi
        read -r _user_proxy
        [ -z "$_user_proxy" ] && return 0
        if ! _validate_proxy_url "$_user_proxy"; then
            if [ "$UI_LANG" = "ru" ]; then
                warn "Неверный формат. Пример: socks5h://10.0.0.5:1080"
            else
                warn "Invalid format. Example: socks5h://10.0.0.5:1080"
            fi
            _attempts=$((_attempts + 1))
            continue
        fi

        # B2: before curl is installed, the package-manager bootstrap (apk/opkg)
        # needs an HTTP(S) proxy via env — it cannot use SOCKS, and BusyBox wget
        # can't do SOCKS either. Reject socks5/socks5h here instead of letting it
        # silently fail to bootstrap curl/jq on a clean router.
        if ! command -v curl >/dev/null 2>&1; then
            case "$_user_proxy" in
                socks5://*|socks5h://*)
                    if [ "$UI_LANG" = "ru" ]; then
                        warn "SOCKS-прокси не может поднять apk/opkg до установки curl. Используйте http:// или https:// прокси на этом шаге."
                    else
                        warn "SOCKS proxy cannot bootstrap apk/opkg before curl is installed. Use an http:// or https:// proxy here."
                    fi
                    _attempts=$((_attempts + 1))
                    continue
                    ;;
            esac
        fi

        printf "  Testing proxy... "
        _apply_user_proxy "$_user_proxy"
        if _probe_github_reachable; then
            echo "OK"
            if [ "$UI_LANG" = "ru" ]; then
                ok "Прокси работает, используется только для этой установки."
            else
                ok "Proxy works — used only for this install run."
            fi
            return 0
        fi
        echo "FAILED"
        _teardown_user_proxy
        _attempts=$((_attempts + 1))
    done

    if [ "$UI_LANG" = "ru" ]; then
        warn "Прокси не сработал за 3 попытки. Продолжаем без него."
    else
        warn "Proxy did not work after 3 attempts. Continuing without it."
    fi
    return 0
}

# ── Safe bot stop: kills main process AND orphaned watchdog subshells ──────────
# procd sends SIGTERM→SIGKILL to the main loop but watchdog subshells can
# survive as zombies and keep sending duplicate alerts / holding state files.
# Strategy:
#   1. init.d stop  — clean procd shutdown (SIGTERM→SIGKILL on main loop)
#   2. kill by PID file — target the specific main PID written at startup
#   3. killall -9  — catch any remaining processes matching the script name
#   4. Short sleep — let the OS reap zombie entries
safe_stop_bot() {
    local _pid_file="/tmp/podkop_bot/bot.pid"
    local _pid_file_legacy="/tmp/podkop_bot.pid"
    local _stopped=0

    # Step 1: procd-managed stop
    if [ -f "$INIT_PATH" ]; then
        printf "$(msg stopping_via_initd)"
        "$INIT_PATH" stop >/dev/null 2>&1
        sleep 1
        echo "$(msg done_word)"
        _stopped=1
    fi

    # Step 2: kill by PID file (main loop PID written by bot at startup).
    # Check new BOT_DIR path first, then legacy flat path for pre-v0.14.1 installs.
    for _pid_file_try in "$_pid_file" "$_pid_file_legacy"; do
        [ -f "$_pid_file_try" ] || continue
        _main_pid=$(cat "$_pid_file_try" 2>/dev/null)
        if [ -n "$_main_pid" ] && kill -0 "$_main_pid" 2>/dev/null; then
            printf "$(printf "$(msg killing_main_pid)" "$_main_pid")"
            kill "$_main_pid" 2>/dev/null
            sleep 1
            kill -9 "$_main_pid" 2>/dev/null
            echo "$(msg done_word)"
        fi
        rm -f "$_pid_file_try"
    done

    # Step 3: killall -9 by script name — catches watchdog subshells, any
    #         leftover ash processes running podkop_bot that survived above.
    #         We match on the basename to avoid killing this installer itself.
    _bot_basename=$(basename "$BOT_PATH")
    if killall -0 "$_bot_basename" 2>/dev/null; then
        printf "$(printf "$(msg killing_remaining_procs)" "$_bot_basename")"
        killall -9 "$_bot_basename" 2>/dev/null
        sleep 1
        echo "$(msg done_word)"
    fi

    # Step 4: reap zombies via wait (only works for children, best-effort)
    wait 2>/dev/null || true

    # Step 5: clean up all runtime/IPC files from /tmp to prevent stale state
    # from affecting the new version (wrong route keys, stale nudge timestamps, etc.)
    cleanup_bot_runtime_files
}

cleanup_bot_runtime_files() {
    local _removed=0

    # v0.14.1+: all state lives under /tmp/podkop_bot/ — wipe volatile files,
    # preserve offset and active_section (bot needs them across restarts).
    if [ -d "/tmp/podkop_bot" ]; then
        for _f in \
            /tmp/podkop_bot/state           /tmp/podkop_bot/health_state \
            /tmp/podkop_bot/socks_state     /tmp/podkop_bot/socks_probe \
            /tmp/podkop_bot/socks_reprobe_ts /tmp/podkop_bot/route_cmd \
            /tmp/podkop_bot/last_menu_msg   /tmp/podkop_bot/last_alert_msg \
            /tmp/podkop_bot/username        /tmp/podkop_bot/id \
            /tmp/podkop_bot/tag_name_cache.txt /tmp/podkop_bot/tag_uri_cache.txt \
            /tmp/podkop_bot/uci_links_cache.txt /tmp/podkop_bot/main_route \
            /tmp/podkop_bot/main_route_key  /tmp/podkop_bot/last_nudge \
            /tmp/podkop_bot/unauth          /tmp/podkop_bot/last_cmd \
            /tmp/podkop_bot/last_reload_ts  /tmp/podkop_bot/reload_ts \
            /tmp/podkop_bot/pubip_cache.txt /tmp/podkop_bot/cl_cache.txt \
            /tmp/podkop_bot/cl_cache_ts     /tmp/podkop_bot/probe_ts \
            /tmp/podkop_bot/bot.pid         /tmp/podkop_bot/podkop_bot.pid \
        ; do
            [ -f "$_f" ] || continue
            rm -f "$_f" && _removed=$((_removed + 1))
        done
        rm -rf /tmp/podkop_bot/pubip_refresh.lockdir 2>/dev/null || true
    fi

    # Legacy flat paths (pre-v0.14.1) — clean on older installs / downgrade.
    for _f in \
        /tmp/podkop_bot_state           /tmp/podkop_bot_health_state \
        /tmp/podkop_bot_socks_state     /tmp/podkop_bot_socks_probe \
        /tmp/podkop_bot_socks_reprobe_ts /tmp/podkop_bot_route_cmd \
        /tmp/podkop_bot_last_menu_msg   /tmp/podkop_bot_last_alert_msg \
        /tmp/podkop_bot_username        /tmp/podkop_bot_id \
        /tmp/podkop_bot_main_route      /tmp/podkop_bot_main_route_key \
        /tmp/podkop_bot.pid             /tmp/podkop_bot_last_nudge \
        /tmp/podkop_bot_unauth          /tmp/podkop_bot_last_cmd \
        /tmp/podkop_bot_last_reload_ts  /tmp/podkop_pubip_cache.txt \
        /tmp/podkop_cl_cache.txt        /tmp/podkop_cl_cache_ts \
        /tmp/podkop_tag_uri_cache.txt   /tmp/podkop_uci_links_cache.txt \
        /tmp/podkop_tag_name_cache.txt \
    ; do
        [ -f "$_f" ] || continue
        rm -f "$_f" && _removed=$((_removed + 1))
    done
    rm -rf /tmp/podkop_pubip_refresh.lockdir 2>/dev/null || true

    # Leftover mktemp-based temp files (any version)
    rm -f /tmp/podkop_req.* /tmp/podkop_bot_update.* /tmp/podkop_updates.* \
        /tmp/podkop_clash.* /tmp/podkop_ip[1-5].* /tmp/podkop_pubip.* 2>/dev/null || true

    [ "$_removed" -gt 0 ] && info "Cleaned up ${_removed} runtime files."
}

# Validate socks5[h]://host:port — format + port must be 1-65535
validate_socks_url() {
    local _url="$1"
    # Contract matches podkop_bot 0.17.0 fallback_socks: optional user:pass@ auth
    # and an optional local mnemonic after '#'. No whitespace anywhere in the
    # endpoint (the list is space-separated). Keep this in sync with the bot's
    # _handle_fallback_socks validation regex.
    #   socks5h://[user[:pass]@]host:port[#Name]
    echo "$_url" | grep -qE '^socks5h?://([^:@/#[:space:]]+(:[^@/#[:space:]]+)?@)?[^:@/#[:space:]]+:[0-9]{1,5}(#[^#[:space:]]*)?$' || return 1
    # Extract the port from the ENDPOINT (strip mnemonic, then creds, then take
    # the number after the last ':'), not blindly from the whole string.
    local _ep _port
    _ep="${_url%%#*}"
    _port=$(printf '%s' "$_ep" | sed 's|.*@||; s|.*:||')
    case "$_port" in ''|*[!0-9]*) return 1 ;; esac
    awk -v p="$_port" 'BEGIN { exit (p >= 1 && p <= 65535) ? 0 : 1 }'
}

# _validate_downloaded_script: sanity-check a downloaded shell script before
# trusting it — catches the case where curl/wget "succeeded" but actually
# saved an HTML error page, an empty file, or a truncated/corrupt download
# (network blips mid-transfer). Two checks:
#   1. First line starts with a shebang (#!) — rules out HTML/JSON/text.
#   2. `ash -n` (or sh -n as fallback) reports no syntax errors.
# Returns 0 if the file looks like a valid, parseable shell script.
_validate_downloaded_script() {
    local _f="$1"
    [ -s "$_f" ] || return 1
    head -1 "$_f" | grep -q '^#!' || return 1
    if command -v ash >/dev/null 2>&1; then
        ash -n "$_f" 2>/dev/null || return 1
    else
        sh -n "$_f" 2>/dev/null || return 1
    fi
    return 0
}

# ── Unattended config loader ────────────────────────────────────────────────
_load_unattended_config() {
    [ -z "$UA_CONFIG" ] && return 0
    [ -f "$UA_CONFIG" ] || die "Config file not found: $UA_CONFIG" 13
    if ! command -v jq >/dev/null 2>&1; then
        _bootstrap_jq
    fi
    if ! command -v jq >/dev/null 2>&1; then
        die "jq is required to parse --config and could not be installed automatically. Install jq manually: opkg/apk install jq" 13
    fi
    if ! jq -e . "$UA_CONFIG" >/dev/null 2>&1; then
        die "Config file is not valid JSON: $UA_CONFIG" 13
    fi
    UA_LANG=$(jq -r '.lang // "en"' "$UA_CONFIG" 2>/dev/null)
    UA_BOT_TOKEN=$(jq -r '.bot_token // ""' "$UA_CONFIG" 2>/dev/null)
    UA_CHAT_ID=$(jq -r '.chat_id // ""' "$UA_CONFIG" 2>/dev/null)
    UA_ADMIN_IDS=$(jq -r '.admin_ids // ""' "$UA_CONFIG" 2>/dev/null)
    UA_ANON_ADMINS=$(jq -r '.allow_anonymous_admins // "1"' "$UA_CONFIG" 2>/dev/null)
    UA_FALLBACK_SOCKS=$(jq -r '.fallback_socks // ""' "$UA_CONFIG" 2>/dev/null)
    UA_SETUP_INIT=$(jq -r '.setup_init // "1"' "$UA_CONFIG" 2>/dev/null)
    UA_START_NOW=$(jq -r '.start_now // "1"' "$UA_CONFIG" 2>/dev/null)
}

# _bootstrap_jq: minimal, self-contained package-manager detection + jq
# install, used ONLY when --config needs parsing and jq isn't present yet.
# Runs before the full PKG_MANAGER/dependency block later in the script —
# that block re-detects PKG_MANAGER and re-checks curl/jq anyway, so running
# this early is redundant-but-safe, not a duplicate-install risk (pkg_install
# is idempotent on an already-installed package on both opkg and apk).
_bootstrap_jq() {
    local _bs_mgr=""
    if command -v apk >/dev/null 2>&1; then
        _bs_mgr="apk"
    elif command -v opkg >/dev/null 2>&1; then
        _bs_mgr="opkg"
    else
        return 1
    fi
    case "$_bs_mgr" in
        apk)  apk update >/dev/null 2>&1; apk add jq >/dev/null 2>&1 ;;
        opkg) opkg update >/dev/null 2>&1; opkg install jq >/dev/null 2>&1 ;;
    esac
}
# ── Lock (prevents concurrent installer runs — important for unattended mode
#       where luci-app-podkop-bot's rpcd backend might be triggered twice) ────
# Read-only actions (status, check, check-token) never mutate anything and must
# not contend for the lock: check-token in particular makes a network getMe that
# can take seconds, and the LuCI Setup Wizard may call it repeatedly — blocking
# on (or being blocked by) a stale/concurrent install lock would make token
# validation hang or fail for no reason. Only install/update/uninstall lock.
case "$UA_ACTION" in
    status|check|check-token) : ;;   # read-only, no lock
    *) _acquire_lock ;;
esac

# ── Unattended: update the LuCI web UI, then exit ──────────────────────────────
# Self-contained: fetch the latest release asset and launch a detached install.
# Runs before the bot-oriented OS/dependency machinery because it targets a
# different package and must survive an rpcd restart triggered by its own
# install. The rpcd backend invokes this as: --unattended --action update-luci
if [ "$UNATTENDED" = "1" ] && [ "$UA_ACTION" = "update-luci" ]; then
    _update_luci_app
    _rc=$?
    _release_lock 2>/dev/null || true
    exit $_rc
fi

# ── Pure-output guard for status/check (Fix 1) ─────────────────────────────────
# luci-app-podkop-bot's rpcd backend pipes `--action status` straight into a
# JSON parser. Every echo/info/step/warn call between here and the JSON print
# below must NOT reach stdout for that case — save the real stdout on fd 3,
# then point fd 1 at /dev/null for the duration of detection. The final JSON
# (or the plain-text "check" result) is printed via fd 3 and is the only
# thing that ever reaches the caller's stdout.
_QUIET_STATUS=0
if [ "$UNATTENDED" = "1" ] && { [ "$UA_ACTION" = "status" ] || [ "$UA_ACTION" = "check" ] || [ "$UA_ACTION" = "check-token" ]; }; then
    _QUIET_STATUS=1
    exec 3>&1 1>/dev/null
fi

# ── Check OS ───────────────────────────────────────────────────────────────────
if ! grep -qE "OpenWrt|immortalwrt|ImmortalWrt" "$OS_RELEASE_FILE" 2>/dev/null; then
    if [ "$UNATTENDED" = "1" ]; then
        echo "ERROR: $(msg os_check_fail)" >&2
        _release_lock
        exit 11
    fi
    die "$(msg os_check_fail)"
fi

# ── Language selection ────────────────────────────────────────────────────────
# Resolution order: --lang flag > unattended config "lang" field > interactive
# prompt > default "en". Unattended mode never prompts — it only affects log
# wording, not behavior, so defaulting to "en" silently is safe.
if [ -n "$LANG_FORCED" ]; then
    case "$LANG_FORCED" in
        ru) UI_LANG="ru" ;;
        en) UI_LANG="en" ;;
        *)  echo "WARNING: unknown --lang '$LANG_FORCED', defaulting to en" ;;
    esac
elif [ "$UNATTENDED" = "1" ]; then
    _load_unattended_config
    case "$UA_LANG" in
        ru) UI_LANG="ru" ;;
        *)  UI_LANG="en" ;;
    esac
else
    echo ""
    printf '%s' "$(msg ask_lang)"
    read -r _lang_choice
    case "$_lang_choice" in
        2|ru|RU|Ru) UI_LANG="ru" ;;
        *)          UI_LANG="en" ;;
    esac
fi

echo ""
echo "==========================================="
echo "$(msg title)"
echo "  v${INSTALLER_VERSION}"
echo "==========================================="

# ── Detect package manager (opkg vs apk) ──────────────────────────────────────
# OpenWrt 23.05 / 24.10  → opkg
# OpenWrt 25.x+          → apk (Alpine Package Keeper)
PKG_MANAGER=""
if command -v apk >/dev/null 2>&1; then
    PKG_MANAGER="apk"
elif command -v opkg >/dev/null 2>&1; then
    PKG_MANAGER="opkg"
else
    _ver=$(grep "^VERSION_ID=" "$OS_RELEASE_FILE" 2>/dev/null | cut -d'"' -f2)
    _major=$(echo "$_ver" | cut -d'.' -f1)
    if echo "$_major" | grep -qE '^[0-9]+$' && [ "$_major" -ge 25 ] 2>/dev/null; then
        PKG_MANAGER="apk"
    else
        PKG_MANAGER="opkg"
    fi
    unset _ver _major
fi

OWRT_VERSION=$(grep '^VERSION_ID=' "$OS_RELEASE_FILE" 2>/dev/null | cut -d'"' -f2)
echo ""
info "$(msg owrt_version): ${OWRT_VERSION:-unknown}"
info "$(msg pkg_manager_label): ${PKG_MANAGER}"
info "$(msg hostname_label): $(cat /proc/sys/kernel/hostname 2>/dev/null || echo unknown)"

# ── Check podkop is installed + detect variant ─────────────────────────────────
step "$(msg detecting_variant)"
PODKOP_OK=0
if [ -f "/usr/bin/podkop" ] || [ -f "/usr/sbin/podkop" ] || [ -f "/usr/bin/podkop-plus" ] || [ -f "/usr/bin/forkop" ] || [ -f "/usr/bin/netshift" ]; then
    PODKOP_OK=1
fi
# Also check via package manager (covers cases where binary lives elsewhere)
if [ "$PODKOP_OK" = "0" ]; then
    case "$PKG_MANAGER" in
        apk)  apk info podkop >/dev/null 2>&1 && PODKOP_OK=1
              apk info forkop >/dev/null 2>&1 && PODKOP_OK=1
              apk info podkop-plus >/dev/null 2>&1 && PODKOP_OK=1
              apk info netshift >/dev/null 2>&1 && PODKOP_OK=1 ;;
        opkg) opkg list-installed 2>/dev/null | grep -qE "^podkop " && PODKOP_OK=1
              opkg list-installed 2>/dev/null | grep -qE "^forkop " && PODKOP_OK=1
              opkg list-installed 2>/dev/null | grep -qE "^podkop-plus " && PODKOP_OK=1
              opkg list-installed 2>/dev/null | grep -qE "^netshift " && PODKOP_OK=1 ;;
    esac
fi
# Check UCI config exists (covers both legacy "podkop" and Plus's "podkop-plus")
if [ "$PODKOP_OK" = "0" ]; then
    if uci -q get podkop.settings >/dev/null 2>&1 || uci -q get forkop.settings >/dev/null 2>&1 || uci -q get podkop-plus.settings >/dev/null 2>&1 || uci -q get netshift.settings >/dev/null 2>&1; then
        PODKOP_OK=1
    fi
fi

PODKOP_VARIANT=$(detect_podkop_variant)

if [ "$PODKOP_OK" = "0" ]; then
    warn "$(msg podkop_not_found)"
    warn "$(msg podkop_required)"
    echo ""
    echo "  $(msg podkop_install_first)"
    echo ""
    echo "  • $(msg podkop_variant_original)"
    echo "      wget -O - https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh | sh"
    echo ""
    echo "  • $(msg podkop_variant_netshift_line)"
    echo "      wget -O - https://raw.githubusercontent.com/yandexru45/netshift/refs/heads/main/install.sh | sh"
    echo ""
    echo "  • $(msg podkop_variant_forkop_line)"
    echo "      wget -O - https://raw.githubusercontent.com/ushan0v/forkop/refs/heads/main/install.sh | sh"
    echo ""
    echo "  $(msg podkop_docs_line)"
    echo ""
    if [ "$UNATTENDED" = "1" ]; then
        # Unattended install with no podkop present is allowed (bot will run
        # in a degraded state) but logged loudly, since there is no human to
        # confirm "continue anyway".
        warn "$(msg unattended_no_podkop)"
    else
        printf '%s' "$(msg continue_anyway)"
        read -r CONT_NO_PODKOP
        [ "$CONT_NO_PODKOP" != "y" ] && [ "$CONT_NO_PODKOP" != "Y" ] && \
            die "$(msg install_aborted)"
        warn "$(msg continuing_no_podkop)"
    fi
else
    PODKOP_VER=""
    SINGBOX_VER=""
    # variant-first: look up the package matching the detected variant first, so
    # a leftover 'podkop' package on a NetShift box can't shadow the real version.
    case "$PODKOP_VARIANT" in
        forkop)   _pkg_name="forkop" ;;
        plus)     _pkg_name="podkop-plus" ;;
        netshift) _pkg_name="netshift" ;;
        *)        _pkg_name="podkop" ;;
    esac
    case "$PKG_MANAGER" in
        apk)
            PODKOP_VER=$(apk info "$_pkg_name" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            # fallbacks in case variant detection and package naming disagree
            [ -z "$PODKOP_VER" ] && PODKOP_VER=$(apk info forkop 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            [ -z "$PODKOP_VER" ] && PODKOP_VER=$(apk info podkop 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            [ -z "$PODKOP_VER" ] && PODKOP_VER=$(apk info podkop-plus 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            [ -z "$PODKOP_VER" ] && PODKOP_VER=$(apk info netshift 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            SINGBOX_VER=$(apk info sing-box 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        opkg)
            PODKOP_VER=$(opkg list-installed 2>/dev/null | grep "^${_pkg_name} " | awk '{print $3}' | sed 's/^v//')
            [ -z "$PODKOP_VER" ] && PODKOP_VER=$(opkg list-installed 2>/dev/null | grep "^forkop " | awk '{print $3}' | sed 's/^v//')
            [ -z "$PODKOP_VER" ] && PODKOP_VER=$(opkg list-installed 2>/dev/null | grep "^podkop " | awk '{print $3}' | sed 's/^v//')
            [ -z "$PODKOP_VER" ] && PODKOP_VER=$(opkg list-installed 2>/dev/null | grep "^podkop-plus " | awk '{print $3}' | sed 's/^v//')
            [ -z "$PODKOP_VER" ] && PODKOP_VER=$(opkg list-installed 2>/dev/null | grep "^netshift " | awk '{print $3}' | sed 's/^v//')
            SINGBOX_VER=$(opkg list-installed 2>/dev/null | grep "^sing-box " | awk '{print $3}' | sed 's/^v//')
            ;;
    esac
    ok "$(msg podkop_found)${PODKOP_VER:+ (v${PODKOP_VER})} — $(msg variant_word): $(variant_label "$PODKOP_VARIANT")"
    [ -n "$SINGBOX_VER" ] && info "sing-box: v${SINGBOX_VER}"
fi

# ── Unattended: status / check actions exit here, before any mutation ─────────
# ── Unattended: check-token — validate a bot token via Telegram getMe with
# SOCKS fallover, emit a flat JSON result, exit. Used by the LuCI Setup Wizard
# (TZ 9.4) so token validation goes through the same fallback-aware transport
# as the installer, not a naive direct curl. Reads the token from --config
# (bot_token field). Network-only, no mutation, runs before OS/dep heavy init.
if [ "$UNATTENDED" = "1" ] && [ "$UA_ACTION" = "check-token" ]; then
    _load_unattended_config
    _ct_token="$UA_BOT_TOKEN"
    # Restore real stdout (fd 3) — banner/log went to /dev/null via the
    # _QUIET_STATUS guard above; from here, printf emits pure JSON to the caller.
    exec 1>&3 3>&-
    if [ -z "$_ct_token" ]; then
        printf '{"valid":false,"reason":"empty_token","detail":"bot_token not provided in config"}\n'
        _release_lock 2>/dev/null
        exit 0
    fi
    _ct_resp=$(_curl_socks_fallover 10 "https://api.telegram.org/bot${_ct_token}/getMe")
    if echo "$_ct_resp" | grep -q '"ok":true'; then
        _ct_user=$(echo "$_ct_resp" | jq -r '.result.username // "unknown"' 2>/dev/null)
        [ -z "$_ct_user" ] && _ct_user="unknown"
        if [ -n "$_last_socks_route" ]; then _ct_route="$_last_socks_route"; else _ct_route="direct"; fi
        printf '{"valid":true,"username":"%s","route":"%s"}\n' "$_ct_user" "$_ct_route"
    else
        # Distinguish "Telegram reachable but rejected token" from "no transport".
        if [ -z "$(_get_socks_endpoints)" ] && ! curl -fsS --connect-timeout 6 --max-time 8 -o /dev/null "https://api.telegram.org" 2>/dev/null; then
            _ct_reason="telegram_unreachable"
            _ct_detail="Telegram direct blocked and no SOCKS available"
        elif echo "$_ct_resp" | grep -q '"ok":false'; then
            _ct_reason="token_invalid"
            _ct_detail="Telegram rejected the token"
        else
            _ct_reason="network_timeout"
            _ct_detail="No response from Telegram (timeout or all transports failed)"
        fi
        printf '{"valid":false,"reason":"%s","detail":"%s"}\n' "$_ct_reason" "$_ct_detail"
    fi
    _release_lock 2>/dev/null
    exit 0
fi

if [ "$UNATTENDED" = "1" ] && { [ "$UA_ACTION" = "status" ] || [ "$UA_ACTION" = "check" ]; }; then
    [ -f "$BOT_PATH" ] && _ua_installed=1
    _ua_bot_ver=$(grep '^BOT_VERSION=' "$BOT_PATH" 2>/dev/null | cut -d'"' -f2)
    [ -z "$_ua_bot_ver" ] && _ua_bot_ver="unknown"
    # Liveness via /proc scan, NOT `init.d status`: bot <=0.15.1 shipped
    # incomplete init scripts whose `status` returns 0 even when dead, which
    # made both this installer and luci-app-podkop-bot report a running bot
    # when it was stopped. The bot runs as `/bin/sh /usr/bin/podkop_bot` (plus a
    # forked child); one live match suffices. Exclude the init wrapper/rc.common.
    for _c in /proc/[0-9]*/cmdline; do
        _cl=$(tr '\0' ' ' < "$_c" 2>/dev/null) || continue
        case "$_cl" in
            *"/etc/init.d/podkop_bot"*) continue ;;
            *rc.common*) continue ;;
            *"/usr/bin/podkop_bot"*) _ua_running=1; break ;;
        esac
    done
    # Fallback: bot may be running directly (not via init.d). Check the
    # single-instance lock file the bot writes at startup — if the PID in
    # it is alive and belongs to a podkop_bot process, the bot is running.
    if [ "$_ua_running" = "0" ]; then
        _lock_pid=$(cat /tmp/podkop_bot/podkop_bot.pid 2>/dev/null)
        if [ -n "$_lock_pid" ] && [ -d "/proc/$_lock_pid" ] && \
           grep -qa 'podkop_bot' "/proc/$_lock_pid/cmdline" 2>/dev/null; then
            _ua_running=1
        fi
    fi
    # Lightweight boolean flags for the LuCI Setup Wizard (18t.7 / 18b.3) — all
    # cheap, no network. Wizard uses these to decide intercept-to-setup vs Overview
    # without a heavy UCI parse from the frontend.
    _ua_config_exists=0
    [ -f /etc/config/podkop_bot ] && _ua_config_exists=1
    _ua_service_enabled=0
    [ -f "$INIT_PATH" ] && "$INIT_PATH" enabled >/dev/null 2>&1 && _ua_service_enabled=1
    _ua_token_set=0
    [ -n "$(uci -q get podkop_bot.settings.bot_token 2>/dev/null)" ] && _ua_token_set=1
    _ua_chatid_set=0
    [ -n "$(uci -q get podkop_bot.settings.chat_id 2>/dev/null)" ] && _ua_chatid_set=1

    # Restore real stdout (fd 3) for the ONLY output this mode ever emits.
    exec 1>&3 3>&-
    if [ "$UA_ACTION" = "status" ]; then
        printf '{"installed":%s,"running":%s,"bot_version":"%s","podkop_variant":"%s","podkop_version":"%s","pkg_manager":"%s","openwrt_version":"%s","installer_version":"%s","config_exists":%s,"service_enabled":%s,"bot_token_configured":%s,"chat_id_configured":%s}\n' \
            "$([ "$_ua_installed" = "1" ] && echo true || echo false)" \
            "$([ "$_ua_running" = "1" ] && echo true || echo false)" \
            "$_ua_bot_ver" "$PODKOP_VARIANT" "${PODKOP_VER:-unknown}" "$PKG_MANAGER" "${OWRT_VERSION:-unknown}" \
            "$INSTALLER_VERSION" \
            "$([ "$_ua_config_exists" = "1" ] && echo true || echo false)" \
            "$([ "$_ua_service_enabled" = "1" ] && echo true || echo false)" \
            "$([ "$_ua_token_set" = "1" ] && echo true || echo false)" \
            "$([ "$_ua_chatid_set" = "1" ] && echo true || echo false)"
    else
        # check: just verify environment is sane for an install — exit 0 if
        # OK to proceed, non-zero codes per the header's exit-code table.
        command -v curl >/dev/null 2>&1 || { echo "curl missing"; _release_lock; exit 14; }
        echo "OK: environment checks passed (podkop=${PODKOP_OK}, variant=${PODKOP_VARIANT})"
    fi
    _release_lock
    exit 0
fi

# ── Package manager wrappers ───────────────────────────────────────────────────
pkg_update() {
    case "$PKG_MANAGER" in
        apk)  apk update >/dev/null 2>&1 ;;
        opkg) opkg update >/dev/null 2>&1 ;;
    esac
}

pkg_is_installed() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        apk)  apk info "$pkg" >/dev/null 2>&1 ;;
        opkg) opkg list-installed 2>/dev/null | grep -q "^${pkg} " ;;
    esac
}

pkg_install() {
    local pkg="$1"
    case "$PKG_MANAGER" in
        apk)  apk add "$pkg" >/dev/null 2>&1 ;;
        opkg) opkg install "$pkg" >/dev/null 2>&1 ;;
    esac
}

# ── Check existing installation (moved ahead of dependency install — this
#    check only reads UCI/filesystem, no curl/jq required, and we need to
#    know HAS_EXISTING before deciding whether to offer a bootstrap proxy) ──
echo ""
EXISTING_TOKEN=$(uci_get bot_token)
EXISTING_CHAT=$(uci_get chat_id)
HAS_EXISTING=0
[ -f "$BOT_PATH" ] && [ -n "$EXISTING_TOKEN" ] && [ -n "$EXISTING_CHAT" ] && HAS_EXISTING=1

# ── Bootstrap proxy prompt (fresh install only) ────────────────────────────
# A fresh install has no podkop_bot fallback_socks yet and may not have
# podkop's Mixed Proxy enabled either — exactly the situation where the
# installer could otherwise have zero transport for both the package
# manager (apk/opkg update + curl/jq install, right below) and the bot
# script download later. Updates/uninstalls always have at least the
# bot's own fallback_socks to fall back on, so this is skipped for them.
[ "$HAS_EXISTING" = "0" ] && _maybe_ask_user_proxy

# ── Install dependencies ───────────────────────────────────────────────────────
step "$(msg downloading_deps)"
info "$(msg updating_index)"
if ! pkg_update; then
    warn "$(msg index_update_failed)"
    warn "$(msg retry_opkg_update_hint)"
fi

for pkg in curl jq; do
    if pkg_is_installed "$pkg"; then
        info "$(printf "$(msg pkg_already_installed)" "$pkg")"
    else
        printf "$(printf "$(msg installing_pkg)" "$pkg")"
        if pkg_install "$pkg"; then
            echo "OK"
        else
            echo "FAILED"
            die "Failed to install $pkg. Run 'opkg update' manually and retry." 14
        fi
    fi
done

# ── Unattended: uninstall action — skip prompts entirely ──────────────────────
# Unattended uninstall is intentionally NOT gated behind the YES/REMOVE double
# confirmation used in interactive mode — the caller (luci-app-podkop-bot
# rpcd backend) is expected to have already confirmed with the human in its
# own UI before invoking this script. Requiring a second confirmation here
# would make unattended mode unusable for its intended caller.
if [ "$UNATTENDED" = "1" ] && [ "$UA_ACTION" = "uninstall" ]; then
    step "$(msg uninstalling_unattended)"
    safe_stop_bot
    if [ -f "$INIT_PATH" ]; then
        "$INIT_PATH" stop >/dev/null 2>&1
        "$INIT_PATH" disable >/dev/null 2>&1
        rm -f "$INIT_PATH"
        info "Removed $INIT_PATH"
    fi
    if [ -f "$BOT_PATH" ]; then
        rm -f "$BOT_PATH"
        info "Removed $BOT_PATH"
    fi
    if uci -q get ${UCI_PKG}.settings >/dev/null 2>&1; then
        uci -q delete ${UCI_PKG} 2>/dev/null || true
        uci commit ${UCI_PKG} 2>/dev/null || true
        rm -f /etc/config/${UCI_PKG} 2>/dev/null || true
        info "Removed /etc/config/${UCI_PKG}"
    fi
    cleanup_bot_runtime_files
    rm -rf /tmp/podkop_bot 2>/dev/null || true
    ok "$(msg unattended_uninstall_complete)"
    _release_lock
    exit 0
fi

if [ "$HAS_EXISTING" = "1" ]; then
    TOKEN_SHORT=$(printf '%s' "$EXISTING_TOKEN" | cut -c1-${TOKEN_DISPLAY_LENGTH})
    INSTALLED_VER=$(grep '^BOT_VERSION=' "$BOT_PATH" 2>/dev/null | cut -d'"' -f2)
    [ -z "$INSTALLED_VER" ] && INSTALLED_VER="unknown"

    if [ "$UNATTENDED" = "1" ]; then
        # Unattended install action on top of an existing install behaves like
        # interactive choice "1" (update, keep settings) — this mirrors what
        # an admin would pick by default and is the only safe non-interactive
        # behavior. Use --action update explicitly if that's the actual intent.
        if [ "$UA_ACTION" = "install" ]; then
            UA_ACTION="update"
            info "$(msg existing_install_to_update)"
        fi
    else
        echo "$(msg existing_detected)"
        echo "  $(msg token_label): ${TOKEN_SHORT}..."
        echo "  $(msg chat_id_label): $EXISTING_CHAT"
        echo "  $(msg version_label): ${INSTALLED_VER}"
        echo ""
        echo "$(msg menu_intro)"
        echo "$(msg menu_1)"
        echo "$(msg menu_2)"
        echo "$(msg menu_3)"
        echo "$(msg menu_4)"
        printf '%s' "$(msg menu_prompt)"
        read -r CHOICE
        echo ""
    fi

    # Unattended update goes straight into the update branch below; map it
    # onto the same CHOICE variable the interactive case statement uses.
    [ "$UNATTENDED" = "1" ] && [ "$UA_ACTION" = "update" ] && CHOICE=1

    case "$CHOICE" in
        2)
            info "$(msg reinstalling)"
            ;;
        3)
            ok "$(msg skipped_kept)"
            _release_lock
            exit 0
            ;;
        4)
            # ── Uninstall flow (interactive only — unattended uninstall
            #    already handled and exited above) ─────────────────────────
            echo "==========================================="
            echo "$(msg uninstall_title)"
            echo "==========================================="
            echo ""
            echo "$(msg uninstall_will_remove)"
            printf "$(msg uninstall_item_bin)\n" "$BOT_PATH"
            printf "$(msg uninstall_item_init)\n" "$INIT_PATH"
            printf "$(msg uninstall_item_uci)\n" "${UCI_PKG}"
            echo "$(msg uninstall_item_uci_detail)"
            echo "$(msg uninstall_item_tmp)"
            echo ""
            echo "$(msg uninstall_not_touched)"
            echo ""
            printf "$(msg uninstall_type_yes)"
            read -r UNINSTALL_CONFIRM1
            if [ "$UNINSTALL_CONFIRM1" != "YES" ]; then
                ok "$(msg uninstall_cancelled)"
                _release_lock
                exit 0
            fi
            echo ""
            printf "$(msg uninstall_type_remove)"
            read -r UNINSTALL_CONFIRM2
            if [ "$UNINSTALL_CONFIRM2" != "REMOVE" ]; then
                ok "$(msg uninstall_cancelled)"
                _release_lock
                exit 0
            fi
            echo ""
            step "$(msg stopping_bot_service)"
            safe_stop_bot
            if [ -f "$INIT_PATH" ]; then
                "$INIT_PATH" stop >/dev/null 2>&1
                "$INIT_PATH" disable >/dev/null 2>&1
                rm -f "$INIT_PATH"
                info "$(printf "$(msg removed)" "$INIT_PATH")"
            fi
            step "$(msg removing_bot_binary)"
            if [ -f "$BOT_PATH" ]; then
                rm -f "$BOT_PATH"
                info "$(printf "$(msg removed)" "$BOT_PATH")"
            fi
            step "$(msg removing_uci_config)"
            if uci -q get ${UCI_PKG}.settings >/dev/null 2>&1; then
                uci -q delete ${UCI_PKG} 2>/dev/null || true
                uci commit ${UCI_PKG} 2>/dev/null || true
                rm -f /etc/config/${UCI_PKG} 2>/dev/null || true
                info "$(printf "$(msg removed)" "/etc/config/${UCI_PKG}")"
            fi
            step "$(msg cleaning_runtime)"
            cleanup_bot_runtime_files
            rm -rf /tmp/podkop_bot 2>/dev/null || true
            echo ""
            echo "==========================================="
            echo "$(msg uninstall_complete)"
            echo "==========================================="
            echo ""
            echo "$(msg podkop_untouched_running)"
            echo "$(msg reinstall_later)"
            echo ""
            _release_lock
            exit 0
            ;;
        1|*)
            # ── Update flow ────────────────────────────────────────────────────
            step "$(msg checking_updates)"
            REMOTE_VER=$(_curl_socks_fallover 10 "$VERSION_URL" | head -1 | tr -d '\r\n\t ')
            [ -z "$REMOTE_VER" ] && REMOTE_VER="unknown"

            echo ""
            printf "$(msg installed_label)\n" "${INSTALLED_VER}"
            printf "$(msg available_label)\n" "${REMOTE_VER}"
            echo ""

            if [ "$UNATTENDED" = "1" ]; then
                if [ "$INSTALLED_VER" = "$REMOTE_VER" ] && [ "$REMOTE_VER" != "unknown" ]; then
                    echo "$(msg already_up_to_date_noninteractive)"
                    _release_lock
                    exit 0
                fi
            else
                if [ "$INSTALLED_VER" = "$REMOTE_VER" ] && [ "$REMOTE_VER" != "unknown" ]; then
                    echo "$(msg already_up_to_date)"
                    printf "$(msg update_anyway)"
                    read -r FORCE_UPDATE
                    [ "$FORCE_UPDATE" != "y" ] && [ "$FORCE_UPDATE" != "Y" ] && {
                        ok "$(msg no_changes_made)"
                        _release_lock
                        exit 0
                    }
                else
                    printf "$(printf "$(msg update_confirm)" "${INSTALLED_VER}" "${REMOTE_VER}")"
                    read -r CONFIRM_UPDATE
                    [ "$CONFIRM_UPDATE" = "n" ] || [ "$CONFIRM_UPDATE" = "N" ] && {
                        ok "$(msg update_cancelled)"
                        _release_lock
                        exit 0
                    }
                fi
            fi

            # Stop all bot processes (main loop + watchdog subshells) before
            # replacing the binary — prevents zombie health daemons.
            safe_stop_bot

            # ── Staged, rollback-safe bot script update ─────────────────────
            # Never download straight into $BOT_PATH: if the download silently
            # returns an HTTP error page or a truncated file, the *only* copy
            # of the bot would be replaced with garbage with no way back.
            # Sequence: download to /tmp → validate (shebang + ash -n) →
            # back up current binary → swap in the new one → start → if the
            # service fails to come up, restore the backup automatically.
            printf "$(printf "$(msg downloading_bot_v)" "${REMOTE_VER}")"
            _bot_new="/tmp/podkop_bot.new"
            _bot_bak="${BOT_PATH}.bak"
            rm -f "$_bot_new"
            download_file "$BOT_URL" "$_bot_new"
            if ! _validate_downloaded_script "$_bot_new"; then
                rm -f "$_bot_new"
                die "Downloaded bot script failed validation — update aborted, existing install untouched." 15
            fi
            chmod +x "$_bot_new"
            echo "OK"

            # Reap any live/zombie bot forks BEFORE swapping the binary, so a
            # legacy init that left children running can't leave them polling
            # the old token alongside the new one (409 / zombie accumulation).
            _reap_bot_forks

            [ -f "$BOT_PATH" ] && cp -f "$BOT_PATH" "$_bot_bak" 2>/dev/null
            mv -f "$_bot_new" "$BOT_PATH"

            # Update init.d script if available in repo
            # Use direct download attempt — wget --spider is unreliable on BusyBox
            _init_tmp=$(mktemp /tmp/podkop_bot_init.XXXXXX)
            _init_bak="${INIT_PATH}.bak"
            if download_file_optional "$INIT_URL" "$_init_tmp" 2>/dev/null && \
               [ -s "$_init_tmp" ] && head -1 "$_init_tmp" | grep -q 'rc.common'; then
                printf "$(msg updating_init)"
                [ -f "$INIT_PATH" ] && cp -f "$INIT_PATH" "$_init_bak" 2>/dev/null
                mv -f "$_init_tmp" "$INIT_PATH"
                chmod +x "$INIT_PATH"
                echo "OK"
            else
                rm -f "$_init_tmp"
                : # init.d script unchanged (no repo update available)
            fi

            # Force-heal a legacy init.d (bot <=0.15.1: no stop_service, no fork
            # cleanup — the root cause of zombie accumulation). If the installed
            # init still lacks fork cleanup after the repo-update attempt above,
            # replace it with the canonical working init. Back up first so the
            # rollback path below can restore it if the new service won't start.
            if _init_is_legacy; then
                printf "$(msg updating_init)"
                [ -f "$INIT_PATH" ] && [ ! -f "$_init_bak" ] && cp -f "$INIT_PATH" "$_init_bak" 2>/dev/null
                _write_working_init
                "$INIT_PATH" enable >/dev/null 2>&1
                echo "OK"
            fi

            ok "$(printf "$(msg updated_to_v)" "${REMOTE_VER}")"
            echo ""

            # Restart service — roll back automatically if it fails to come up.
            _update_start_ok=0
            if [ -f "$INIT_PATH" ]; then
                printf "$(msg starting_service)"
                "$INIT_PATH" start >/dev/null 2>&1
                sleep 2
                if _bot_alive; then
                    echo "OK"
                    ok "$(msg service_restarted_ok)"
                    _update_start_ok=1
                else
                    echo "FAILED"
                fi
            else
                info "$(printf "$(msg no_init_start_manually)" "$BOT_PATH")"
                _update_start_ok=1  # no service manager to verify against — don't roll back
            fi

            if [ "$_update_start_ok" = "0" ]; then
                warn "$(msg rollback_warn)"
                _reap_bot_forks
                if [ -f "$_bot_bak" ]; then
                    mv -f "$_bot_bak" "$BOT_PATH"
                    chmod +x "$BOT_PATH"
                    [ -f "$_init_bak" ] && mv -f "$_init_bak" "$INIT_PATH" && chmod +x "$INIT_PATH"
                    "$INIT_PATH" start >/dev/null 2>&1
                    sleep 2
                    if _bot_alive; then
                        warn "$(msg rollback_ok)"
                    else
                        warn "$(msg rollback_also_failed)"
                        warn "$(msg rollback_check_logs)"
                    fi
                else
                    warn "$(printf "$(msg rollback_no_backup)" "$_bot_bak")"
                fi
                rm -f "$_bot_bak" "$_init_bak" 2>/dev/null
                die "Update failed: new version did not start. See warnings above for rollback result." 18
            fi
            rm -f "$_bot_bak" "$_init_bak" 2>/dev/null

            echo ""
            echo "==========================================="
            echo "$(msg update_complete_title)"
            echo "==========================================="
            echo ""
            printf "$(msg bot_script_label)\n" "$BOT_PATH"
            printf "$(msg version_v_label)\n" "${REMOTE_VER}"
            printf "$(msg config_label)\n" "${UCI_PKG}"
            echo ""
            echo "$(msg useful_commands)"
            echo "$(msg live_logs_cmd)"
            echo "$(msg restart_bot_cmd)"
            echo "$(msg check_status_cmd)"
            echo ""
            echo "GitHub: https://github.com/Medvedolog/podkop_bot"
            _release_lock
            exit 0
            ;;
    esac
fi
# ── Download bot script (staged) ──────────────────────────────────────────────
# Stage in /tmp → validate → back up existing (reinstall) → swap. For a fresh
# install there's no existing binary to back up (normal). For a reinstall this
# prevents wiping a working binary if the new download is broken/truncated.
step "$(msg downloading_bot)"
_bot_stage="/tmp/podkop_bot.new"
rm -f "$_bot_stage"
download_file "$BOT_URL" "$_bot_stage"
_validate_downloaded_script "$_bot_stage" || {
    rm -f "$_bot_stage"
    die "Downloaded bot script failed validation (not a valid shell script, or has syntax errors). Aborting before swap — existing install untouched." 15
}
chmod +x "$_bot_stage"
# Back up existing binary (reinstall case) so it can be restored manually if the
# new one misbehaves. Fresh install: nothing to back up.
[ -f "$BOT_PATH" ] && cp -f "$BOT_PATH" "${BOT_PATH}.bak" 2>/dev/null || true
mv -f "$_bot_stage" "$BOT_PATH"
INSTALLED_VER=$(grep '^BOT_VERSION=' "$BOT_PATH" 2>/dev/null | cut -d'"' -f2)
ok "$(printf "$(msg downloaded_v)" "${INSTALLED_VER:-unknown}" "$BOT_PATH")"

# ── Bot token ─────────────────────────────────────────────────────────────────
if [ "$UNATTENDED" = "1" ]; then
    BOT_TOKEN="$UA_BOT_TOKEN"
    [ -z "$BOT_TOKEN" ] && die "Config field 'bot_token' is required for install." 12
else
    section "$(msg section_bot_config)"
    if [ "$UI_LANG" = "ru" ]; then
        echo "Токен бота нужен, чтобы podkop_bot мог отправлять и получать сообщения"
        echo "от вашего имени через Telegram Bot API."
        echo ""
        echo "Как получить токен:"
        echo "  1. Откройте чат с @BotFather в Telegram"
        echo "  2. Отправьте команду /newbot (или /token для существующего бота)"
        echo "  3. Следуйте инструкциям, скопируйте выданный токен"
        echo ""
        echo "Токен выглядит так: 123456789:ABCdefGHIjklMNOpqrSTUvwxYZ"
        echo "Он будет сохранён в /etc/config/podkop_bot — доступ только у root."
        echo ""
        printf "Токен Telegram-бота (от @BotFather):\n> "
    else
        echo "The bot token lets podkop_bot send and receive messages on your"
        echo "behalf via the Telegram Bot API."
        echo ""
        echo "How to get a token:"
        echo "  1. Open a chat with @BotFather in Telegram"
        echo "  2. Send /newbot (or /token for an existing bot)"
        echo "  3. Follow the prompts, copy the token it gives you"
        echo ""
        echo "Token looks like: 123456789:ABCdefGHIjklMNOpqrSTUvwxYZ"
        echo "It will be stored in /etc/config/podkop_bot — root-only access."
        echo ""
        printf "Telegram bot token (from @BotFather):\n> "
    fi
    read -r BOT_TOKEN
    [ -z "$BOT_TOKEN" ] && die "Bot token cannot be empty."
fi

printf "$(msg verifying_token)"
TG_CHECK=$(_curl_socks_fallover 10 "https://api.telegram.org/bot${BOT_TOKEN}/getMe")
if ! echo "$TG_CHECK" | grep -q '"ok":true'; then
    echo "FAILED"
    if [ -z "$(_get_socks_endpoints)" ]; then
        warn "$(msg tg_direct_failed)"
        warn "$(msg tg_blocked_hint1)"
        warn "$(msg tg_blocked_hint2)"
    else
        warn "$(msg tg_verify_failed_generic)"
    fi
    if [ "$UNATTENDED" = "1" ]; then
        die "Token validation failed in unattended mode — aborting (no human to confirm 'continue anyway')." 17
    fi
    printf "$(msg continue_with_token)"
    read -r CONT
    [ "$CONT" != "y" ] && [ "$CONT" != "Y" ] && die "Installation aborted."
else
    BOT_NAME=$(echo "$TG_CHECK" | jq -r '.result.username // "unknown"' 2>/dev/null)
    if [ -n "$_last_socks_route" ]; then
        echo "OK — @${BOT_NAME} (via ${_last_socks_route})"
    else
        echo "OK — @${BOT_NAME}"
    fi
fi

# ── Chat ID ───────────────────────────────────────────────────────────────────
if [ "$UNATTENDED" = "1" ]; then
    CHAT_ID="$UA_CHAT_ID"
    [ -z "$CHAT_ID" ] && die "Config field 'chat_id' is required for install." 12
else
    echo ""
    if [ "$UI_LANG" = "ru" ]; then
        echo "Chat ID — это куда бот будет присылать уведомления (статус, алерты,"
        echo "результаты команд). Это может быть:"
        echo "  - ваш личный chat_id (если пишете боту в личку)"
        echo "  - chat_id группы или супергруппы (бот должен быть её участником)"
        echo ""
        echo "Узнать свой chat_id: напишите боту @userinfobot любое сообщение,"
        echo "он покажет ваш числовой ID."
        echo ""
        printf "Chat ID или User ID для уведомлений\n(личный чат, группа или супергруппа):\n> "
    else
        echo "Chat ID is where the bot sends notifications (status, alerts,"
        echo "command results). This can be:"
        echo "  - your personal chat_id (if messaging the bot directly)"
        echo "  - a group or supergroup chat_id (bot must be a member)"
        echo ""
        echo "To find your chat_id: message @userinfobot anything in Telegram,"
        echo "it replies with your numeric ID."
        echo ""
        printf "Chat ID or User ID for alerts\n(private chat, group, or supergroup):\n> "
    fi
    read -r CHAT_ID
    [ -z "$CHAT_ID" ] && die "Chat ID cannot be empty."
fi

# ── Additional admin IDs ───────────────────────────────────────────────────────
if [ "$UNATTENDED" = "1" ]; then
    ADMIN_IDS_RAW="$UA_ADMIN_IDS"
else
    echo ""
    if [ "$UI_LANG" = "ru" ]; then
        echo "Дополнительные администраторы (необязательно)."
        echo "Эти пользователи могут управлять ботом наравне с основным chat_id —"
        echo "например, второй член семьи или соадмин роутера."
        echo "Список user_id через пробел. Пример: 123456789 987654321"
        printf "(Enter, чтобы пропустить)\n> "
    else
        echo "Additional admin User IDs (optional)."
        echo "These users can control the bot in addition to the main chat_id —"
        echo "useful for a second household member or co-admin of the router."
        echo "Space-separated list of numeric user IDs. Example: 123456789 987654321"
        printf "(Enter to skip)\n> "
    fi
    read -r ADMIN_IDS_RAW
fi

# ── Anonymous group admins ─────────────────────────────────────────────────────
if [ "$UNATTENDED" = "1" ]; then
    ANON_ADMINS_VAL="${UA_ANON_ADMINS:-1}"
else
    echo ""
    if [ "$UI_LANG" = "ru" ]; then
        echo "Если бот добавлен в группу с анонимными админами (сообщения от имени"
        echo "группы, а не личного аккаунта), Telegram не показывает их user_id."
        echo "Разрешить таким анонимным админам управлять ботом? Безопасно включить,"
        echo "если в группе только доверенные администраторы."
        printf "Разрешить анонимным админам группы управлять ботом? (Y/n): "
    else
        echo "If the bot is added to a group with anonymous admins (messages sent"
        echo "as the group, not a personal account), Telegram hides their user_id."
        echo "Allow such anonymous admins to control the bot? Safe to enable if"
        echo "only trusted administrators are in the group."
        printf "Allow anonymous group admins to control the bot? (Y/n): "
    fi
    read -r ANON_ADMINS
    ANON_ADMINS_VAL=1
    [ "$ANON_ADMINS" = "n" ] || [ "$ANON_ADMINS" = "N" ] && ANON_ADMINS_VAL=0
fi

# ── Fallback SOCKS ────────────────────────────────────────────────────────────
FALLBACK_SOCKS_LIST=""
if [ "$UNATTENDED" = "1" ]; then
    FALLBACK_SOCKS_LIST="$UA_FALLBACK_SOCKS"
else
    echo ""
    if [ "$UI_LANG" = "ru" ]; then
        section "Резервные SOCKS-прокси (необязательно, но рекомендуется)"
        echo "Если podkop/sing-box остановится, бот теряет основной SOCKS5-туннель"
        echo "(tier1) для связи с Telegram при блокировке провайдером."
        echo "Резервные SOCKS-записи (tier2) позволяют боту достучаться до Telegram"
        echo "через независимый прокси, пока основной туннель восстанавливается."
        echo ""
        echo "Формат: socks5h://ХОСТ:ПОРТ  (socks5h резолвит DNS через прокси —"
        echo "        рекомендуется)"
        echo "        socks5://ХОСТ:ПОРТ"
        echo ""
        echo "Примеры:"
        echo "  socks5h://192.168.2.10:1080   — другой роутер в сети с прокси"
        echo "  socks5h://10.0.0.5:18088      — VPS или резервный туннель"
        echo ""
        printf "Добавить резервные SOCKS-записи? (y/N): "
    else
        section "$(msg section_fallback_socks)"
        echo "If podkop/sing-box stops, the bot loses its primary SOCKS5 tunnel."
        echo "Fallback SOCKS entries (tier2) let the bot keep reaching Telegram"
        echo "via an independent proxy while the tunnel recovers."
        echo ""
        echo "Format: socks5h://HOST:PORT  (socks5h resolves DNS through proxy — recommended)"
        echo "        socks5://HOST:PORT"
        echo ""
        echo "Examples:"
        echo "  socks5h://192.168.2.10:1080   — another router on LAN running a proxy"
        echo "  socks5h://10.0.0.5:18088      — VPS or secondary tunnel"
        echo ""
        printf "Add fallback SOCKS entries? (y/N): "
    fi
    read -r ADD_FB

    if [ "$ADD_FB" = "y" ] || [ "$ADD_FB" = "Y" ]; then
        echo ""
        if [ "$UI_LANG" = "ru" ]; then
            echo "Введите по одной записи на строку. Пустая строка = готово."
        else
            echo "Enter one entry per line. Empty line = done."
        fi
        _fb_n=1
        while true; do
            if [ "$UI_LANG" = "ru" ]; then
                printf "  Запись %d (или Enter для завершения): " "$_fb_n"
            else
                printf "  Entry %d (or Enter to finish): " "$_fb_n"
            fi
            read -r _fb_entry
            [ -z "$_fb_entry" ] && break
            if validate_socks_url "$_fb_entry"; then
                FALLBACK_SOCKS_LIST="${FALLBACK_SOCKS_LIST} ${_fb_entry}"
                ok "Added: $_fb_entry"
                _fb_n=$((_fb_n + 1))
            else
                if [ "$UI_LANG" = "ru" ]; then
                    warn "Неверный формат. Ожидается: socks5h://ХОСТ:ПОРТ или socks5://ХОСТ:ПОРТ"
                else
                    warn "Invalid format. Expected: socks5h://HOST:PORT or socks5://HOST:PORT"
                fi
            fi
        done
        _fb_count=$(echo "$FALLBACK_SOCKS_LIST" | tr ' ' '\n' | grep -c '.')
        [ "$_fb_count" -gt 0 ] && ok "$_fb_count fallback SOCKS entry(s) configured." \
                               || info "No valid entries added. Skipping fallback SOCKS."
    fi
fi
# ── Write UCI config ───────────────────────────────────────────────────────────
step "$(msg writing_uci_config)"

[ -f "/etc/config/${UCI_PKG}" ] || touch "/etc/config/${UCI_PKG}" \
    || die "Cannot create /etc/config/${UCI_PKG} — check filesystem." 16

uci -q delete "${UCI_PKG}.${UCI_SEC}" 2>/dev/null
uci set "${UCI_PKG}.${UCI_SEC}=settings" \
    || die "uci set failed — check /etc/config/ permissions." 16

uci set "${UCI_PKG}.${UCI_SEC}.bot_token=${BOT_TOKEN}"
uci set "${UCI_PKG}.${UCI_SEC}.chat_id=${CHAT_ID}"
uci set "${UCI_PKG}.${UCI_SEC}.allow_anonymous_admins=${ANON_ADMINS_VAL}"
uci set "${UCI_PKG}.${UCI_SEC}.transport=auto"
uci set "${UCI_PKG}.${UCI_SEC}.health_interval=60"
uci set "${UCI_PKG}.${UCI_SEC}.alert_notify=1"
uci set "${UCI_PKG}.${UCI_SEC}.startup_notify=1"

# admin_ids: space-separated list → multiple uci add_list calls (safe for spaces/special chars)
# uci set with spaces in value is unreliable — use uci list approach via config file
if [ -n "$ADMIN_IDS_RAW" ]; then
    for _aid in $ADMIN_IDS_RAW; do
        # Validate: admin IDs must be numeric
        if echo "$_aid" | grep -qE '^-?[0-9]+$'; then
            uci add_list "${UCI_PKG}.${UCI_SEC}.admin_ids=${_aid}"
        else
            warn "$(printf "$(msg skipping_invalid_admin)" "$_aid")"
        fi
    done
fi

# fallback_socks: one uci add_list per entry
if [ -n "$FALLBACK_SOCKS_LIST" ]; then
    for _fb in $FALLBACK_SOCKS_LIST; do
        [ -n "$_fb" ] && uci add_list "${UCI_PKG}.${UCI_SEC}.fallback_socks=${_fb}"
    done
fi

uci commit "$UCI_PKG" || die "uci commit failed." 16
# Enforce 0600 explicitly: umask only affects newly-created files, not a config
# that already existed as 0644 (e.g. from a prior install). Token lives here.
chmod 600 "/etc/config/${UCI_PKG}" 2>/dev/null || true
ok "$(printf "$(msg config_written)" "${UCI_PKG}")"

# Show what was written
echo ""
echo "$(msg uci_summary_title)"
echo "  ┌─ bot_token  : $(uci_get bot_token | cut -c1-${TOKEN_DISPLAY_LENGTH})..."
echo "  ├─ chat_id    : $(uci_get chat_id)"
_aids=$(uci -q get ${UCI_PKG}.${UCI_SEC}.admin_ids 2>/dev/null || echo "(none)")
echo "  ├─ admin_ids  : ${_aids}"
_fbs=$(uci -q show ${UCI_PKG}.${UCI_SEC}.fallback_socks 2>/dev/null \
    | cut -d= -f2- | tr "'" ' ' | tr '\n' ' ' || echo "(none)")
echo "  ├─ fb_socks   : ${_fbs:-(none)}"
echo "  └─ transport  : auto"

# ── Init script / autostart ────────────────────────────────────────────────────
if [ "$UNATTENDED" = "1" ]; then
    SETUP_INIT="${UA_SETUP_INIT:-1}"
    [ "$SETUP_INIT" = "0" ] && SETUP_INIT="n" || SETUP_INIT="y"
else
    section "$(msg section_autostart)"
    printf "$(msg ask_setup_autostart)"
    read -r SETUP_INIT
fi

if [ "$SETUP_INIT" != "n" ] && [ "$SETUP_INIT" != "N" ]; then
    # Try to download init script from repo; validate it looks like an rc.common script
    _init_tmp=$(mktemp /tmp/podkop_bot_init.XXXXXX)
    INIT_OK=0
    printf "$(msg downloading_initd)"
    if download_file_optional "$INIT_URL" "$_init_tmp" 2>/dev/null && \
       [ -s "$_init_tmp" ] && head -1 "$_init_tmp" | grep -q 'rc.common'; then
        mv "$_init_tmp" "$INIT_PATH"
        INIT_OK=1
        echo "OK"
    else
        rm -f "$_init_tmp"
        echo "$(msg initd_not_available)"
    fi

    if [ "$INIT_OK" = "0" ]; then
        # No repo init available — write the canonical procd init (single source
        # in _write_working_init; carries fork-cleanup to prevent 409/zombies).
        _write_working_init
        info "$(msg generated_init_script)"
    fi

    chmod +x "$INIT_PATH"
    "$INIT_PATH" enable >/dev/null 2>&1
    ok "$(printf "$(msg autostart_enabled)" "$INIT_PATH")"
else
    info "$(printf "$(msg autostart_skipped)" "$BOT_PATH")"
fi

# ── Start now ─────────────────────────────────────────────────────────────────
if [ "$UNATTENDED" = "1" ]; then
    START_NOW="${UA_START_NOW:-1}"
    [ "$START_NOW" = "0" ] && START_NOW="n" || START_NOW="y"
else
    echo ""
    printf "$(msg ask_start_now)"
    read -r START_NOW
    echo ""
fi

if [ "$START_NOW" != "n" ] && [ "$START_NOW" != "N" ]; then
    if [ -f "$INIT_PATH" ]; then
        printf "$(msg starting_via_initd)"
        "$INIT_PATH" start >/dev/null 2>&1
        sleep 2
        if "$INIT_PATH" status >/dev/null 2>&1; then
            echo "OK"
            ok "$(msg bot_started_initd)"
        else
            echo "$(msg unknown_fallback_direct)"
            "$BOT_PATH" &
            _direct_pid="$!"
            ok "$(printf "$(msg bot_started_directly)" "$_direct_pid")"
            # In unattended mode: init.d failed to supervise, but the direct
            # start may have worked. Only exit 18 if the process is truly dead.
            if [ "$UNATTENDED" = "1" ]; then
                sleep 2
                if [ -d "/proc/$_direct_pid" ]; then
                    warn "Bot started directly (not via procd). init.d integration may need manual fix."
                    _release_lock; exit 0
                else
                    _release_lock; exit 18
                fi
            fi
        fi
    else
        "$BOT_PATH" &
        ok "$(printf "$(msg bot_started)" "$!")"
    fi
else
    info "$(msg bot_not_started)"
    info "  /etc/init.d/podkop_bot start"
    info "$(printf "$(msg or_manually)" "$BOT_PATH")"
fi

# ── Detect Mixed Proxy / YACD status for recommendations block ────────────────
# Re-detect tier1 the same way _get_socks_endpoints does, but keep the pieces
# (section, port, enabled-flag) separate so we can explain *why* to enable
# things rather than just listing a command.
_rec_pkg=$(_podkop_uci_pkg)
_rec_field="connection_type"
[ "$_rec_pkg" = "podkop-plus" ] && _rec_field="action"

_rec_mixed_sec=""
_rec_mixed_sec=$(uci -q show "$_rec_pkg" 2>/dev/null \
    | grep -E "^${_rec_pkg}\.[^.=]+=section$" \
    | while IFS='=' read -r _k _v; do
        _s=$(printf '%s' "$_k" | cut -d. -f2)
        _ct=$(uci -q get "${_rec_pkg}.${_s}.${_rec_field}" 2>/dev/null)
        { [ "$_ct" = "proxy" ] || [ "$_ct" = "connection" ]; } && echo "$_s" && break
    done | head -1)

_rec_mixed_enabled=0
_rec_mixed_port=""
if [ -n "$_rec_mixed_sec" ]; then
    [ "$(uci -q get "${_rec_pkg}.${_rec_mixed_sec}.mixed_proxy_enabled" 2>/dev/null)" = "1" ] && _rec_mixed_enabled=1
    _rec_mixed_port=$(uci -q get "${_rec_pkg}.${_rec_mixed_sec}.mixed_proxy_port" 2>/dev/null)
fi

_rec_yacd_enabled=0
[ "$(uci -q get "${_rec_pkg}.settings.enable_yacd" 2>/dev/null)" = "1" ] && _rec_yacd_enabled=1

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==========================================="
if [ "$UI_LANG" = "ru" ]; then
    echo "  Установка завершена!"
else
    echo "  Installation complete!"
fi
echo "==========================================="
echo ""

if [ "$UI_LANG" = "ru" ]; then
    echo "  Скрипт бота      : $BOT_PATH"
    echo "  Конфиг           : /etc/config/${UCI_PKG}"
    echo "  Версия бота      : ${INSTALLED_VER:-unknown}"
    echo "  Менеджер пакетов : ${PKG_MANAGER}"
    echo "  Вариант podkop   : $(variant_label "$PODKOP_VARIANT") (${PODKOP_VARIANT})"
    [ -n "$PODKOP_VER" ]   && echo "  Версия podkop    : ${PODKOP_VER}"
    [ -n "$SINGBOX_VER" ]  && echo "  Версия sing-box  : ${SINGBOX_VER}"
    if [ "$_PROXY_BOOTSTRAPPED" = "1" ]; then
        echo "  Прокси установки : временно использовался, отключится при выходе"
        echo "                     (не сохранён ни в системе, ни в /etc/config)"
    fi
    echo ""
    echo "Полезные команды:"
    echo "  logread -f | grep podkop-bot          — логи в реальном времени"
    echo "  /etc/init.d/podkop_bot restart        — перезапустить бота"
    echo "  /etc/init.d/podkop_bot status         — проверить статус"
    echo ""
    echo "Изменить конфиг:"
    echo "  uci show ${UCI_PKG}"
    echo "  uci add_list ${UCI_PKG}.${UCI_SEC}.fallback_socks='socks5h://ХОСТ:ПОРТ'"
    echo "  uci set ${UCI_PKG}.${UCI_SEC}.health_interval=60"
    echo "  uci commit ${UCI_PKG} && /etc/init.d/podkop_bot restart"
    echo ""
    echo "-------------------------------------------"
    echo "  Рекомендации по настройке podkop"
    echo "-------------------------------------------"
    echo ""
    if [ "$_rec_mixed_enabled" = "1" ]; then
        echo "[✓] Mixed Proxy уже включён (порт ${_rec_mixed_port:-?})."
        echo "    Это даёт боту резервный путь к Telegram, если прямое"
        echo "    соединение заблокировано провайдером — именно тем способом,"
        echo "    которым этот установщик сам пользуется для фолбэк-загрузки."
    else
        echo "[ ] Mixed Proxy не включён (или не найден). Рекомендуется включить:"
        echo "      LuCI → Podkop → [секция] → Mixed Proxy Port → задать порт"
        echo "      (например 2080) и включить."
        echo "    Зачем: без него бот не сможет связаться с Telegram через"
        echo "    туннель podkop, если прямое соединение с api.telegram.org"
        echo "    заблокировано — а в России это частый случай. Mixed Proxy —"
        echo "    это и основной транспорт бота (tier1), и резервный канал"
        echo "    самого установщика при обновлениях."
    fi
    echo ""
    if [ "$_rec_yacd_enabled" = "1" ]; then
        echo "[✓] YACD включён — это просто веб-интерфейс sing-box для браузера."
        echo "    Бот не зависит от этой настройки: он обращается к Clash API"
        echo "    напрямую (127.0.0.1), который sing-box поднимает всегда,"
        echo "    независимо от того, включён YACD или нет."
    else
        echo "[ ] YACD выключён — это нормально, бот работает и без него."
        echo "    YACD — лишь готовый веб-интерфейс для просмотра соединений"
        echo "    глазами в браузере; сам Clash API, которым пользуется бот"
        echo "    для карточек Status / Tunnel Health, работает независимо."
        echo "    Включить YACD стоит только если хотите смотреть состояние"
        echo "    туннеля через браузер сами:"
        echo "      LuCI → Podkop → Advanced → Enable YACD"
        echo "      (держите 'YACD WAN access' выключенным, если роутер"
        echo "      смотрит в интернет напрямую)."
    fi
    echo ""
    echo "GitHub: https://github.com/Medvedolog/podkop_bot"
else
    echo "  Bot script      : $BOT_PATH"
    echo "  Config          : /etc/config/${UCI_PKG}"
    echo "  Bot version     : ${INSTALLED_VER:-unknown}"
    echo "  Pkg mgr         : ${PKG_MANAGER}"
    echo "  Podkop variant  : $(variant_label "$PODKOP_VARIANT") (${PODKOP_VARIANT})"
    [ -n "$PODKOP_VER" ]   && echo "  Podkop version  : ${PODKOP_VER}"
    [ -n "$SINGBOX_VER" ]  && echo "  sing-box version: ${SINGBOX_VER}"
    if [ "$_PROXY_BOOTSTRAPPED" = "1" ]; then
        echo "  Install proxy   : was used temporarily, disabled on exit"
        echo "                    (not saved to the system or to /etc/config)"
    fi
    echo ""
    echo "Useful commands:"
    echo "  logread -f | grep podkop-bot          — live logs"
    echo "  /etc/init.d/podkop_bot restart        — restart bot"
    echo "  /etc/init.d/podkop_bot status         — check status"
    echo ""
    echo "Edit config:"
    echo "  uci show ${UCI_PKG}"
    echo "  uci add_list ${UCI_PKG}.${UCI_SEC}.fallback_socks='socks5h://HOST:PORT'"
    echo "  uci set ${UCI_PKG}.${UCI_SEC}.health_interval=60"
    echo "  uci commit ${UCI_PKG} && /etc/init.d/podkop_bot restart"
    echo ""
    echo "-------------------------------------------"
    echo "  Recommended podkop settings"
    echo "-------------------------------------------"
    echo ""
    if [ "$_rec_mixed_enabled" = "1" ]; then
        echo "[✓] Mixed Proxy is already enabled (port ${_rec_mixed_port:-?})."
        echo "    This gives the bot a fallback path to Telegram if the direct"
        echo "    connection is blocked by your ISP — the same mechanism this"
        echo "    installer itself uses for fallback downloads."
    else
        echo "[ ] Mixed Proxy is not enabled (or not found). Recommended:"
        echo "      LuCI → Podkop → [section] → Mixed Proxy Port → set a port"
        echo "      (e.g. 2080) and enable it."
        echo "    Why: without it, the bot cannot reach Telegram through the"
        echo "    podkop tunnel if direct access to api.telegram.org is"
        echo "    blocked — a common situation in restricted networks. Mixed"
        echo "    Proxy is both the bot's primary transport (tier1) and this"
        echo "    installer's own fallback channel during updates."
    fi
    echo ""
    if [ "$_rec_yacd_enabled" = "1" ]; then
        echo "[✓] YACD is enabled — it's just a browser-based UI for sing-box."
        echo "    The bot doesn't depend on this toggle: it talks to the"
        echo "    Clash API directly (127.0.0.1), which sing-box always runs"
        echo "    regardless of whether YACD is enabled or not."
    else
        echo "[ ] YACD is disabled — that's fine, the bot works without it."
        echo "    YACD is only a ready-made browser UI for watching"
        echo "    connections yourself; the Clash API the bot actually uses"
        echo "    for the Status / Tunnel Health cards runs independently."
        echo "    Enable YACD only if you want to view tunnel status in a"
        echo "    browser yourself:"
        echo "      LuCI → Podkop → Advanced → Enable YACD"
        echo "      (keep 'YACD WAN access' off if the router faces the"
        echo "      internet directly)."
    fi
    echo ""
    echo "GitHub: https://github.com/Medvedolog/podkop_bot"
fi

# ── Offer to install/update the LuCI web UI ────────────────────────────────────
# The bot works entirely from Telegram, but most users also want the web panel.
# Only offered after a bot install/update (not status/check/uninstall). In
# unattended mode it's opt-in via --with-luci; interactively we ask.
if [ "$UA_ACTION" = "install" ] || [ "$UA_ACTION" = "update" ] || [ "$UNATTENDED" != "1" ]; then
    _do_luci=0
    if [ "$UNATTENDED" = "1" ]; then
        [ "${UA_WITH_LUCI:-0}" = "1" ] && _do_luci=1
    else
        echo ""
        if [ "$UI_LANG" = "ru" ]; then
            printf "  Установить/обновить веб-интерфейс (LuCI)? [Y/n]: "
        else
            printf "  Install/update the LuCI web UI? [Y/n]: "
        fi
        read -r _ans
        case "$_ans" in n|N|no|No|NO) _do_luci=0 ;; *) _do_luci=1 ;; esac
    fi
    if [ "$_do_luci" = "1" ]; then
        echo ""
        if [ "$UI_LANG" = "ru" ]; then echo "  Устанавливаю веб-интерфейс…"; else echo "  Installing the web UI…"; fi
        if _update_luci_app; then
            if [ "$UI_LANG" = "ru" ]; then
                echo "  Запущено (в фоне). Лог: $LUCI_UPDATE_LOG"
            else
                echo "  Launched (background). Log: $LUCI_UPDATE_LOG"
            fi
        else
            if [ "$UI_LANG" = "ru" ]; then
                echo "  [!!] Не удалось получить пакет веб-интерфейса. Поставьте вручную из релизов."
            else
                echo "  [!!] Could not fetch the web UI package. Install manually from Releases."
            fi
        fi
    fi
fi

_release_lock
exit 0
