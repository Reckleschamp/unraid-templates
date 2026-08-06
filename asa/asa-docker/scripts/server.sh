#!/usr/bin/env bash

build_server_url() {
    local server_url="${MAP_NAME}?listen"

    server_url+="?SessionName=${SESSION_NAME}"

    if is_true "${RCON_ENABLED}"; then
        if [[ -z "${ADMIN_PASSWORD}" ]]; then
            fatal "ADMIN_PASSWORD must be set when RCON is enabled."
        fi

        server_url+="?RCONEnabled=True"
        server_url+="?RCONPort=${RCON_PORT}"
    else
        server_url+="?RCONEnabled=False"
    fi

    if [[ -n "${SERVER_PASSWORD}" ]]; then
        server_url+="?ServerPassword=${SERVER_PASSWORD}"
    fi

    if [[ -n "${ADMIN_PASSWORD}" ]]; then
        server_url+="?ServerAdminPassword=${ADMIN_PASSWORD}"
    fi

    printf '%s' "${server_url}"
}

build_launch_arguments() {
    local server_url=""
    local extra_arguments=()

    server_url="$(build_server_url)"

    LAUNCH_ARGUMENTS=(
        "${server_url}"
        "-port=${ASA_PORT}"
        "-WinLiveMaxPlayers=${MAX_PLAYERS}"
        "-clusterid=${CLUSTER_ID}"
        "-ClusterDirOverride=Z:\\cluster"
        "-server"
        "-log"
    )

    if [[ -n "${MOD_IDS}" ]]; then
        LAUNCH_ARGUMENTS+=("-mods=${MOD_IDS}")
    fi

    if ! is_true "${BATTLEYE}"; then
        LAUNCH_ARGUMENTS+=("-NoBattlEye")
    fi

    if [[ -n "${EXTRA_SERVER_ARGS:-}" ]]; then
        read -r -a extra_arguments <<<"${EXTRA_SERVER_ARGS}"
        LAUNCH_ARGUMENTS+=("${extra_arguments[@]}")
    fi
}

configure_server_environment() {
    export DISPLAY="${DISPLAY:-:0.0}"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/99}"
    export PROTON_USE_ESYNC="${PROTON_USE_ESYNC:-1}"

    export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_ROOT}"
    export STEAM_COMPAT_DATA_PATH="${PROTON_PREFIX}"

    export SteamAppId="${ASA_APP_ID}"
    export SteamGameId="${ASA_APP_ID}"
    export STEAMAPPID="${ASA_APP_ID}"
}

start_virtual_display() {
    local xvfb_log="${LOG_DIR}/xvfb.log"
    local display_number=""
    local xvfb_display=""
    local start_time=0

    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
        log "Virtual X display is already ready on ${DISPLAY}."
        return
    fi

    mkdir -p "${LOG_DIR}"

    display_number="${DISPLAY#:}"
    display_number="${display_number%%.*}"
    xvfb_display=":${display_number}"

    log "Starting virtual X display on ${xvfb_display}."

    Xvfb "${xvfb_display}" \
        -screen 0 1024x768x24 \
        -nolisten tcp \
        >"${xvfb_log}" 2>&1 &

    XVFB_PID=$!
    start_time="${SECONDS}"

    while ! xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; do
        if ! kill -0 "${XVFB_PID}" 2>/dev/null; then
            fatal "Xvfb exited during startup. Check ${xvfb_log}."
        fi

        if ((SECONDS - start_time >= XVFB_STARTUP_TIMEOUT)); then
            kill "${XVFB_PID}" 2>/dev/null || true
            wait "${XVFB_PID}" 2>/dev/null || true

            XVFB_PID=""

            fatal "Xvfb did not become ready within ${XVFB_STARTUP_TIMEOUT} seconds. Check ${xvfb_log}."
        fi

        sleep 0.05
    done

    log "Virtual X display is ready with PID ${XVFB_PID}."
}

start_asa_log_stream() {
    local asa_log_directory=""

    asa_log_directory="$(dirname "${ASA_LOG_FILE}")"

    mkdir -p "${asa_log_directory}"

    log "Starting live ASA log stream."
    log "ASA log file: ${ASA_LOG_FILE}"

    while [[ ! -f "${ASA_LOG_FILE}" ]]; do
        sleep 0.1

        if [[ -n "${SERVER_PID:-}" ]] &&
            ! kill -0 "${SERVER_PID}" 2>/dev/null; then
            warn "ASA exited before ShooterGame.log was created."
            return
        fi
    done

    tail -n 0 -F "${ASA_LOG_FILE}" 2>/dev/null &

    ASA_LOG_TAIL_PID=$!
}

stop_asa_log_stream() {
    if [[ -z "${ASA_LOG_TAIL_PID:-}" ]]; then
        return
    fi

    if kill -0 "${ASA_LOG_TAIL_PID}" 2>/dev/null; then
        kill "${ASA_LOG_TAIL_PID}" 2>/dev/null || true
        wait "${ASA_LOG_TAIL_PID}" 2>/dev/null || true
    fi

    ASA_LOG_TAIL_PID=""
}

print_server_ready_banner() {
    log "============================================================"
    log "ASA SERVER Accepted RCON connection."
    log "============================================================"
}

wait_for_server_ready() {
    if ! is_true "${RCON_ENABLED}"; then
        warn "RCON is disabled, so server readiness cannot be verified through RCON."
        return 1
    fi

    if wait_for_rcon_ready; then
        print_server_ready_banner
        return 0
    fi

    return 1
}

start_server() {
    local exit_code=0

    require_executable "${PROTON}"
    require_file "${ASA_EXE}"

    build_launch_arguments
    configure_server_environment
    start_virtual_display
    write_launch_information

    log "Starting ASA instance: ${INSTANCE_NAME}"
    log "Map: ${MAP_NAME}"
    log "Session: ${SESSION_NAME}"
    log "Game port: ${ASA_PORT}/UDP"

    if is_true "${RCON_ENABLED}"; then
        log "RCON port: ${RCON_PORT}/TCP"
    else
        log "RCON: disabled"
    fi

    log "Cluster ID: ${CLUSTER_ID}"
    log "Cluster directory: ${CLUSTER_DIR}"
    log "Maximum players: ${MAX_PLAYERS}"
    log "Data directory: ${DATA_DIR}"
    log "Server directory: ${ASA_DIR}"
    log "Native ASA config directory: ${ASA_CONFIG_DIR}"
    log "Proton prefix: ${PROTON_PREFIX}"
    log "Proton directory: ${PROTON_DIR}"
    log "Display: ${DISPLAY}"
    log "XDG runtime directory: ${XDG_RUNTIME_DIR}"

    cd "$(dirname "${ASA_EXE}")"

    start_asa_log_stream

    "${PROTON}" run "${ASA_EXE}" "${LAUNCH_ARGUMENTS[@]}" &
    SERVER_PID=$!

    log "ASA launched under Proton with PID ${SERVER_PID}."

    if is_true "${RCON_ENABLED}"; then
        if ! wait_for_server_ready; then
            warn "ASA did not become ready."

            if [[ -n "${SERVER_PID:-}" ]] &&
                ! kill -0 "${SERVER_PID}" 2>/dev/null; then
                warn "ASA exited before startup was completed."
            fi
        fi
    fi

    set +e
    wait "${SERVER_PID}"
    exit_code=$?
    set -e

    stop_asa_log_stream

    SERVER_PID=""

    copy_asa_debug_files
    stop_debug_monitor

    if [[ "${SHUTDOWN_REQUESTED}" == "true" ]]; then
        log "ASA stopped because the container was shut down."
        return 0
    fi

    if [[ "${exit_code}" -eq 0 ]]; then
        log "ASA exited normally."
    else
        warn "ASA exited unexpectedly with status ${exit_code}."
    fi

    return "${exit_code}"
}