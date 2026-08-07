#!/usr/bin/env bash

wait_for_server_exit() {
    local timeout="${1:-180}"
    local elapsed=0

    while [[ -n "${SERVER_PID:-}" ]] &&
        kill -0 "${SERVER_PID}" 2>/dev/null; do

        if ((elapsed >= timeout)); then
            return 1
        fi

        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 0
}

shutdown_server() {
    local signal="${1:-TERM}"

    if [[ "${SHUTDOWN_REQUESTED}" == "true" ]]; then
        return
    fi

    SHUTDOWN_REQUESTED=true

    log "Container received ${signal}."
    log "Beginning ASA shutdown."

    if [[ -z "${SERVER_PID:-}" ]] ||
        ! kill -0 "${SERVER_PID}" 2>/dev/null; then

        log "ASA is not currently running."
        stop_asa_log_stream
        return
    fi

    if rcon_can_connect; then
        log "RCON connection established."

        log "Broadcasting shutdown notice to players."
        if ! send_rcon_command "Broadcast Server shutting down in"; then
            warn "The RCON Broadcast command failed."
        fi

        sleep 2

        if ! send_rcon_command "SaveWorld"; then
            warn "The RCON SaveWorld command failed."
        fi

        log "Waiting ${SAVE_WAIT_SECONDS} seconds for the save to complete."
        sleep "${SAVE_WAIT_SECONDS}"

        log "Requesting graceful ASA shutdown."

        if ! send_rcon_command "DoExit"; then
            warn "The RCON DoExit command failed."
        fi

        if wait_for_server_exit "${STOP_TIMEOUT}"; then
            log "ASA exited following the RCON shutdown command."
            return
        fi

        warn "ASA did not exit within ${STOP_TIMEOUT} seconds after DoExit."
    else
        warn "RCON is unavailable or ASA is not accepting RCON commands."
    fi

    log "Sending SIGTERM to Proton process ${SERVER_PID}."

    kill -TERM "${SERVER_PID}" 2>/dev/null || true

    if wait_for_server_exit 30; then
        log "ASA exited after SIGTERM."
        return
    fi

    warn "ASA did not exit after SIGTERM."
    warn "Sending SIGKILL to Proton process ${SERVER_PID}."

    kill -KILL "${SERVER_PID}" 2>/dev/null || true

    wait_for_server_exit 5 || true
    stop_asa_log_stream

    log "ASA shutdown sequence completed."
}

register_shutdown_traps() {
    trap 'shutdown_server SIGTERM' TERM
    trap 'shutdown_server SIGINT' INT
}