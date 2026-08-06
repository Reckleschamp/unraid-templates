#!/usr/bin/env bash

set -Eeuo pipefail

# Script location

SCRIPTS_DIR="${SCRIPTS_DIR:-/home/steam/scripts}"

# shellcheck source=/dev/null
source "${SCRIPTS_DIR}/common.sh"

# Internal application paths

STEAMCMD_DIR="${STEAMCMD_DIR:-/home/steam/steamcmd}"
STEAM_ROOT="${STEAM_ROOT:-/home/steam/Steam}"
PROTON_DIR="${PROTON_DIR:-/home/steam/proton}"
DATA_DIR="${DATA_DIR:-/data}"
ASA_DIR="${ASA_DIR:-${DATA_DIR}/server}"
PROTON_PREFIX="${PROTON_PREFIX:-${DATA_DIR}/proton-prefix}"
CLUSTER_DIR="${CLUSTER_DIR:-/cluster}"
LOG_DIR="${LOG_DIR:-${DATA_DIR}/logs}"
DEBUG_DIR="${DEBUG_DIR:-${LOG_DIR}/debug}"
DEBUG_CONTAINER_LOG="${DEBUG_CONTAINER_LOG:-${DEBUG_DIR}/container.log}"
DEBUG_PROTON_DIR="${DEBUG_PROTON_DIR:-${DEBUG_DIR}/proton}"
DEBUG_ASA_DIR="${DEBUG_ASA_DIR:-${DEBUG_DIR}/asa}"

ASA_CONFIG_DIR="${ASA_DIR}/ShooterGame/Saved/Config/WindowsServer"
ASA_LOG_FILE="${ASA_DIR}/ShooterGame/Saved/Logs/ShooterGame.log"
ASA_EXE="${ASA_DIR}/ShooterGame/Binaries/Win64/ArkAscendedServer.exe"

STEAMCMD="${STEAMCMD_DIR}/steamcmd.sh"
PROTON="${PROTON_DIR}/proton"

# Steam application for ARK: Survival Ascended

ASA_APP_ID="${ASA_APP_ID:-2430930}"

# Server settings

INSTANCE_NAME="${INSTANCE_NAME:-ASA Server}"
MAP_NAME="${MAP_NAME:-TheIsland_WP}"
SESSION_NAME="${SESSION_NAME:-ASA Server}"
ASA_PORT="${ASA_PORT:-7777}"
MAX_PLAYERS="${MAX_PLAYERS:-10}"
MOD_IDS="${MOD_IDS:-}"
CLUSTER_ID="${CLUSTER_ID:-cluster}"
SERVER_PASSWORD="${SERVER_PASSWORD:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
RCON_ENABLED="${RCON_ENABLED:-true}"
RCON_PORT="${RCON_PORT:-27020}"
UPDATE_SERVER="${UPDATE_SERVER:-true}"
VALIDATE_SERVER="${VALIDATE_SERVER:-false}"
BATTLEYE="${BATTLEYE:-false}"

# Startup and shutdown timing

XVFB_STARTUP_TIMEOUT="${XVFB_STARTUP_TIMEOUT:-10}"
SERVER_STARTUP_TIMEOUT="${SERVER_STARTUP_TIMEOUT:-600}"
RCON_RETRY_INTERVAL="${RCON_RETRY_INTERVAL:-1}"
STOP_TIMEOUT="${STOP_TIMEOUT:-180}"
SAVE_WAIT_SECONDS="${SAVE_WAIT_SECONDS:-10}"

# Debug settings

DEBUG_LOGGING="${DEBUG_LOGGING:-false}"
DEBUG_LOG_MAX_MB="${DEBUG_LOG_MAX_MB:-100}"

# Runtime state

SERVER_PID=""
XVFB_PID=""
ASA_LOG_TAIL_PID=""
DEBUG_MONITOR_PID=""
SHUTDOWN_REQUESTED=false
LAUNCH_ARGUMENTS=()

# shellcheck source=/dev/null
source "${SCRIPTS_DIR}/paths.sh"
# shellcheck source=/dev/null
source "${SCRIPTS_DIR}/update.sh"
# shellcheck source=/dev/null
source "${SCRIPTS_DIR}/logging.sh"
# shellcheck source=/dev/null
source "${SCRIPTS_DIR}/server.sh"
# shellcheck source=/dev/null
source "${SCRIPTS_DIR}/rcon.sh"
# shellcheck source=/dev/null
source "${SCRIPTS_DIR}/shutdown.sh"

main() {
    prepare_directories
    initialize_debug_logging

    log "Starting ASA container initialization."
    log "Running as UID:GID $(id -u):$(id -g)."

    register_shutdown_traps

    install_or_update_server
    start_server
}

main "$@"