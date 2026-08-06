#!/usr/bin/env bash

rcon_is_available() {
    command -v mcrcon >/dev/null 2>&1
}

rcon_is_configured() {
    [[ -n "${ADMIN_PASSWORD:-}" ]] &&
        [[ -n "${RCON_PORT:-}" ]]
}

send_rcon_command() {
    local command="$1"

    if ! rcon_is_available; then
        warn "RCON command skipped because mcrcon is not installed."
        return 1
    fi

    if ! rcon_is_configured; then
        warn "RCON command skipped because ADMIN_PASSWORD or RCON_PORT is missing."
        return 1
    fi

    mcrcon \
        -H 127.0.0.1 \
        -P "${RCON_PORT}" \
        -p "${ADMIN_PASSWORD}" \
        "${command}"
}

rcon_can_connect() {
    if ! rcon_is_available || ! rcon_is_configured; then
        return 1
    fi

    mcrcon \
        -H 127.0.0.1 \
        -P "${RCON_PORT}" \
        -p "${ADMIN_PASSWORD}" \
        "ListPlayers" \
        >/dev/null 2>&1
}