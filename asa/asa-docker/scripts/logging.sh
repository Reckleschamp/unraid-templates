#!/usr/bin/env bash

write_debug_system_info() {
    local os_name="unknown"

    if [[ -r /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        os_name="${PRETTY_NAME:-unknown}"
    fi

    {
        printf 'Generated: %s\n' "$(date --iso-8601=seconds)"
        printf 'Instance name: %s\n' "${INSTANCE_NAME}"
        printf 'Session name: %s\n' "${SESSION_NAME}"
        printf 'Map: %s\n' "${MAP_NAME}"
        printf 'UID:GID: %s:%s\n' "$(id -u)" "$(id -g)"
        printf 'Operating system: %s\n' "${os_name}"
        printf 'Kernel: %s\n' "$(uname -a)"
        printf 'ASA App ID: %s\n' "${ASA_APP_ID}"
        printf 'Game port: %s/UDP\n' "${ASA_PORT}"
        printf 'RCON port: %s/TCP\n' "${RCON_PORT}"
        printf 'Cluster ID: %s\n' "${CLUSTER_ID}"
        printf 'Data directory: %s\n' "${DATA_DIR}"
        printf 'Server directory: %s\n' "${ASA_DIR}"
        printf 'Config directory: %s\n' "${CONFIG_DIR}"
        printf 'Cluster directory: %s\n' "${CLUSTER_DIR}"
        printf 'Proton directory: %s\n' "${PROTON_DIR}"
        printf 'Proton prefix: %s\n' "${PROTON_PREFIX}"
        printf 'SteamCMD directory: %s\n' "${STEAMCMD_DIR}"
        printf 'Debug log limit: %s MB\n' "${DEBUG_LOG_MAX_MB}"
    } >"${DEBUG_DIR}/system-info.txt"
}

trim_debug_log() {
    local log_file="$1"
    local max_bytes="$2"
    local current_bytes=0
    local temporary_file=""

    [[ -f "${log_file}" ]] || return 0

    current_bytes="$(
        stat -c '%s' "${log_file}" 2>/dev/null ||
            printf '0'
    )"

    if ((current_bytes <= max_bytes)); then
        return 0
    fi

    temporary_file="${log_file}.trim"

    warn "Debug log reached its ${DEBUG_LOG_MAX_MB} MB limit: ${log_file}"

    if tail -c "${max_bytes}" "${log_file}" >"${temporary_file}" 2>/dev/null; then
        # Rewrite the existing file so a process holding it open can continue
        # appending to the same file.
        cat "${temporary_file}" >"${log_file}"
        rm -f "${temporary_file}"
    fi
}

monitor_debug_log_sizes() {
    local max_bytes=$((DEBUG_LOG_MAX_MB * 1024 * 1024))
    local log_file=""

    while true; do
        trim_debug_log "${DEBUG_CONTAINER_LOG}" "${max_bytes}"

        for log_file in "${DEBUG_PROTON_DIR}"/steam-*.log; do
            [[ -f "${log_file}" ]] || continue
            trim_debug_log "${log_file}" "${max_bytes}"
        done

        sleep 15
    done
}

initialize_debug_logging() {
    if ! is_true "${DEBUG_LOGGING}"; then
        export PROTON_LOG=0
        export WINEDEBUG="-all"

        log "Debug logging is disabled."
        return
    fi

    mkdir -p \
        "${DEBUG_DIR}" \
        "${DEBUG_PROTON_DIR}" \
        "${DEBUG_ASA_DIR}"

    # Preserve the current startup log on each restart instead of allowing one
    # container.log file to grow forever.
    if [[ -s "${DEBUG_CONTAINER_LOG}" ]]; then
        mv \
            "${DEBUG_CONTAINER_LOG}" \
            "${DEBUG_CONTAINER_LOG}.$(date '+%Y%m%d-%H%M%S')" \
            2>/dev/null || true
    fi

    # Continue displaying output in Unraid while also storing it persistently.
    exec > >(tee -a "${DEBUG_CONTAINER_LOG}") 2>&1

    export PROTON_LOG=1
    export PROTON_LOG_DIR="${DEBUG_PROTON_DIR}"

    # Target crash handling and DLL-loading failures without enabling Wine's
    # extremely noisy warn+all diagnostics.
    export WINEDEBUG="-all,+seh,+loaddll"

    write_debug_system_info

    monitor_debug_log_sizes &
    DEBUG_MONITOR_PID=$!

    log "Debug logging is enabled."
    log "Debug directory: ${DEBUG_DIR}"
    log "Maximum individual debug log size: ${DEBUG_LOG_MAX_MB} MB"
}

copy_asa_debug_files() {
    if ! is_true "${DEBUG_LOGGING}"; then
        return
    fi

    local asa_log_dir="${ASA_DIR}/ShooterGame/Saved/Logs"
    local source_file=""
    local destination_file=""

    mkdir -p "${DEBUG_ASA_DIR}"

    if [[ -f "${asa_log_dir}/ShooterGame.log" ]]; then
        tail -n 10000 \
            "${asa_log_dir}/ShooterGame.log" \
            >"${DEBUG_ASA_DIR}/ShooterGame.log" \
            2>/dev/null || true
    fi

    for source_file in \
        "${asa_log_dir}"/CrashContext.runtime-xml \
        "${asa_log_dir}"/*.dmp; do

        [[ -f "${source_file}" ]] || continue

        destination_file="${DEBUG_ASA_DIR}/$(basename "${source_file}")"

        cp -f \
            "${source_file}" \
            "${destination_file}" \
            2>/dev/null || true
    done
}

write_launch_information() {
    if ! is_true "${DEBUG_LOGGING}"; then
        return
    fi

    {
        printf 'Executable: %s\n' "${ASA_EXE}"
        printf 'Map: %s\n' "${MAP_NAME}"
        printf 'Game port: %s\n' "${ASA_PORT}"
        printf 'RCON port: %s\n' "${RCON_PORT}"
        printf 'Cluster ID: %s\n' "${CLUSTER_ID}"
        printf 'Cluster directory: %s\n' "${CLUSTER_DIR}"
        printf 'BattlEye enabled: %s\n' "${BATTLEYE}"
        printf 'Extra server arguments: %s\n' "${EXTRA_SERVER_ARGS:-}"
    } >"${DEBUG_DIR}/launch-info.txt"

    # Passwords are intentionally not written to the debug files.
}

stop_debug_monitor() {
    if [[ -z "${DEBUG_MONITOR_PID:-}" ]]; then
        return
    fi

    if kill -0 "${DEBUG_MONITOR_PID}" 2>/dev/null; then
        kill "${DEBUG_MONITOR_PID}" 2>/dev/null || true
        wait "${DEBUG_MONITOR_PID}" 2>/dev/null || true
    fi

    DEBUG_MONITOR_PID=""
}