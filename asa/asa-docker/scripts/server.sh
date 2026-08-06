#!/usr/bin/env bash

build_server_url() {
    local server_url="${MAP_NAME}?listen"

    server_url+="?SessionName=${SESSION_NAME}"
    server_url+="?MaxPlayers=${MAX_PLAYERS}"
    server_url+="?RCONEnabled=True"
    server_url+="?RCONPort=${RCON_PORT}"

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

    server_url="$(build_server_url)"

    LAUNCH_ARGUMENTS=(
        "${server_url}"
        "-port=${ASA_PORT}"
        "-clusterid=${CLUSTER_ID}"
        "-ClusterDirOverride=Z:\\cluster"
        "-server"
        "-log"
    )

    if ! is_true "${BATTLEYE}"; then
        LAUNCH_ARGUMENTS+=("-NoBattlEye")
    fi

    if [[ -n "${EXTRA_SERVER_ARGS:-}" ]]; then
        local extra_arguments=()

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
    local xvfb_pid=""

    if pgrep -x Xvfb >/dev/null 2>&1; then
        log "Virtual X display is already running."
        return
    fi

    mkdir -p "${LOG_DIR}"

    log "Starting virtual X display on ${DISPLAY}."

    Xvfb "${DISPLAY}" \
        -screen 0 1024x768x24 \
        -nolisten tcp \
        >"${xvfb_log}" 2>&1 &

    xvfb_pid=$!

    sleep 2

    if ! kill -0 "${xvfb_pid}" 2>/dev/null; then
        fatal "Xvfb failed to start. Check ${xvfb_log}."
    fi

    log "Virtual X display started with PID ${xvfb_pid}."
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
    log "RCON port: ${RCON_PORT}/TCP"
    log "Cluster ID: ${CLUSTER_ID}"
    log "Cluster directory: ${CLUSTER_DIR}"
    log "Maximum players: ${MAX_PLAYERS}"
    log "Data directory: ${DATA_DIR}"
    log "Server directory: ${ASA_DIR}"
    log "Config directory: ${CONFIG_DIR}"
    log "Proton prefix: ${PROTON_PREFIX}"
    log "Proton directory: ${PROTON_DIR}"
    log "Display: ${DISPLAY}"
    log "XDG runtime directory: ${XDG_RUNTIME_DIR}"

    cd "$(dirname "${ASA_EXE}")"

    "${PROTON}" run "${ASA_EXE}" "${LAUNCH_ARGUMENTS[@]}" &
    SERVER_PID=$!

    log "ASA launched under Proton with PID ${SERVER_PID}."

    set +e
    wait "${SERVER_PID}"
    exit_code=$?
    set -e

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