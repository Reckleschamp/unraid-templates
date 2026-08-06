#!/usr/bin/env bash

prepare_directories() {
    log "Preparing persistent directories."

    require_writable_directory "${DATA_DIR}"
    require_writable_directory "${ASA_DIR}"
    require_writable_directory "${CONFIG_DIR}"
    require_writable_directory "${PROTON_PREFIX}"
    require_writable_directory "${CLUSTER_DIR}"
    require_writable_directory "${ASA_CONFIG_DIR}"

    if is_true "${DEBUG_LOGGING}"; then
        require_writable_directory "${LOG_DIR}"
        require_writable_directory "${DEBUG_DIR}"
        require_writable_directory "${DEBUG_PROTON_DIR}"
        require_writable_directory "${DEBUG_ASA_DIR}"
    fi
}