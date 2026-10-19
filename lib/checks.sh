#!/usr/bin/env bash
# checks.sh - environment and command detection.
#
# Shared by the install engine and the verify engine so both always agree
# on whether a tool is present (important for NVM, which is a shell
# function loaded from ~/.nvm, not a binary on PATH).
#
# This file is sourced, never executed.

[[ -n "${_ITC_CHECKS_LOADED:-}" ]] && return 0
_ITC_CHECKS_LOADED=1

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

apt_package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# ubuntu_version - print VERSION_ID from /etc/os-release (e.g. "24.04").
ubuntu_version() {
    # shellcheck disable=SC1091
    (. /etc/os-release && printf '%s\n' "${VERSION_ID:-tundmatu}")
}

is_supported_ubuntu() {
    case "$(ubuntu_version)" in
        22.04 | 24.04) return 0 ;;
        *) return 1 ;;
    esac
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# load_nvm - load NVM into the current shell. Non-interactive scripts do
# not read ~/.bashrc, so NVM must be sourced explicitly. nvm.sh is not
# "set -u" clean, so strict mode is relaxed while sourcing it.
load_nvm() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    [[ -s "$NVM_DIR/nvm.sh" ]] || return 1
    set +u
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    set -u
}

# tool_available <command> - true if the command is usable INSIDE the distro,
# taking into account tools that only exist after NVM is loaded (nvm, node,
# npm, ...). WSL interop puts Windows tools (/mnt/c/...) on PATH; those must
# NOT count, otherwise a tool installed only on Windows would wrongly satisfy
# the check and the Linux install would be skipped.
tool_available() {
    local cmd="$1" found
    load_nvm >/dev/null 2>&1 || true
    found="$(command -v "$cmd" 2>/dev/null)" || return 1
    [[ "$found" != /mnt/* ]]
}

# tool_ready <id> <command> - tool_available, plus the optional extra check
# check_tool_<id> for tools whose command alone does not prove a working
# install. Used by both the install and the verify engine.
tool_ready() {
    local id="$1" cmd="$2"
    tool_available "$cmd" || return 1
    if declare -F "check_tool_${id}" >/dev/null; then
        "check_tool_${id}"
    fi
}

# check_tool_playwright - the npm package alone cannot run tests: it also
# needs the exact Chromium build it was released with, downloaded to
# ~/.cache/ms-playwright/chromium-<revision>. The revision comes from the
# installed package's browsers.json; INSTALLATION_COMPLETE is written by
# Playwright only after a successful download.
check_tool_playwright() {
    local root revision
    root="$(npm root -g 2>/dev/null)" || return 1
    [[ -f "$root/playwright-core/browsers.json" ]] || return 1
    revision="$(node -p "require('$root/playwright-core/browsers.json').browsers.find(b => b.name === 'chromium').revision" 2>/dev/null)" || return 1
    [[ -f "${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}/chromium-${revision}/INSTALLATION_COMPLETE" ]]
}
