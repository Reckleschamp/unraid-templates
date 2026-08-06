#!/usr/bin/env bash

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

warn() {
    log "WARNING: $*"
}

fatal() {
    log "ERROR: $*"
    exit 1
}

is_true() {
    case "${1,,}" in
        true | yes | y | 1 | on)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

require_file() {
    local path="$1"
    [[ -f "${path}" ]] || fatal "Required file not found: ${path}"
}

require_executable() {
    local path="$1"
    [[ -x "${path}" ]] || fatal "Required executable not found: ${path}"
}

require_writable_directory() {
    local path="$1"
    mkdir -p "${path}"
    [[ -w "${path}" ]] ||
        fatal "${path} is not writable by UID:GID $(id -u):$(id -g)."
}