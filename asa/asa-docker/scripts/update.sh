#!/usr/bin/env bash

install_or_update_server() {
    require_executable "${STEAMCMD}"

    if [[ ! -f "${ASA_EXE}" ]]; then
        log "ASA is not installed."
        log "Installing Steam application ${ASA_APP_ID} into ${ASA_DIR}."

        "${STEAMCMD}" \
            +force_install_dir "${ASA_DIR}" \
            +login anonymous \
            +app_update "${ASA_APP_ID}" validate \
            +quit

    elif is_true "${UPDATE_SERVER}"; then
        log "Checking for ASA server updates."

        local update_command=(
            "${STEAMCMD}"
            +force_install_dir "${ASA_DIR}"
            +login anonymous
            +app_update "${ASA_APP_ID}"
        )

        if is_true "${VALIDATE_SERVER}"; then
            log "Steam file validation is enabled."
            update_command+=(validate)
        fi

        update_command+=(+quit)

        "${update_command[@]}"

    else
        log "Automatic ASA updates are disabled."
    fi

    if [[ ! -f "${ASA_EXE}" ]]; then
        fatal "SteamCMD completed, but ${ASA_EXE} was not found."
    fi
}