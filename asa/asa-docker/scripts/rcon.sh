#!/usr/bin/env bash

rcon_is_available() {
    command -v mcrcon >/dev/null 2>&1
}

rcon_is_configured() {
    is_true "${RCON_ENABLED:-false}" &&
        [[ -n "${ADMIN_PASSWORD:-}" ]] &&
        [[ -n "${RCON_PORT:-}" ]]
}

send_rcon_command() {
    local command=""

    if [[ $# -eq 0 ]]; then
        warn "RCON command skipped because no command was provided."
        return 1
    fi

    command="$*"

    if ! rcon_is_available; then
        warn "RCON command skipped because mcrcon is not installed."
        return 1
    fi

    if ! rcon_is_configured; then
        warn "RCON command skipped because RCON is disabled or not configured."
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

wait_for_rcon_ready() {
    local start_time="${SECONDS}"

    if ! rcon_is_available; then
        warn "Cannot perform the RCON readiness check because mcrcon is missing."
        return 1
    fi

    if ! rcon_is_configured; then
        warn "Cannot perform the RCON readiness check because RCON is not configured."
        return 1
    fi

    log "Waiting for ASA to accept RCON commands."

    while true; do
        if [[ -n "${SERVER_PID:-}" ]] &&
            ! kill -0 "${SERVER_PID}" 2>/dev/null; then
            warn "ASA exited before RCON became available."
            return 1
        fi

        if rcon_can_connect; then
            log "ASA is accepting RCON commands."
            return 0
        fi

        if ((SECONDS - start_time >= SERVER_STARTUP_TIMEOUT)); then
            warn "ASA did not accept RCON commands within ${SERVER_STARTUP_TIMEOUT} seconds."
            return 1
        fi

        sleep "${RCON_RETRY_INTERVAL}"
    done
}