#!/usr/bin/env bash

set -Eeuo pipefail

RCON_HOST="${RCON_HOST:-127.0.0.1}"
RCON_PORT="${RCON_PORT:-27020}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

usage() {
    cat <<'EOF'
Usage:
  asa <command> [arguments]

Commands:
  status
      Test RCON and list connected players.

  players
      List connected players.

  save
      Save the current world.

  dino-wipe
      Destroy all wild creatures.

  broadcast <message>
      Display a server-wide broadcast.

  chat <message>
      Send a server chat message.

  kick <player-id>
      Kick a player.

  ban <player-id>
      Ban a player.

  unban <player-id>
      Remove a player ban.

  exit-server
      Save the world and issue DoExit.

  raw <command>
      Send an unmodified RCON command.

Examples:
  asa players
  asa save
  asa dino-wipe
  asa broadcast Server restarting soon
  asa raw GetGameLog
EOF
}

fatal() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_rcon() {
    command -v mcrcon >/dev/null 2>&1 ||
        fatal "mcrcon is not installed."

    [[ -n "${RCON_PORT}" ]] ||
        fatal "RCON_PORT is not set."

    [[ -n "${ADMIN_PASSWORD}" ]] ||
        fatal "ADMIN_PASSWORD is not set."
}

rcon() {
    require_rcon

    mcrcon \
        -H "${RCON_HOST}" \
        -P "${RCON_PORT}" \
        -p "${ADMIN_PASSWORD}" \
        "$@"
}

require_arguments() {
    local command_name="$1"
    shift

    if [[ $# -eq 0 ]]; then
        fatal "${command_name} requires an argument."
    fi
}

command_name="${1:-}"

if [[ $# -gt 0 ]]; then
    shift
fi

case "${command_name}" in
    status | players)
        rcon "ListPlayers"
        ;;

    save)
        rcon "SaveWorld"
        ;;

    dino-wipe)
        rcon "DestroyWildDinos"
        ;;

    broadcast)
        require_arguments "broadcast" "$@"
        rcon "Broadcast $*"
        ;;

    chat)
        require_arguments "chat" "$@"
        rcon "ServerChat $*"
        ;;

    kick)
        [[ $# -eq 1 ]] ||
            fatal "Usage: asa kick <player-id>"

        rcon "KickPlayer $1"
        ;;

    ban)
        [[ $# -eq 1 ]] ||
            fatal "Usage: asa ban <player-id>"

        rcon "BanPlayer $1"
        ;;

    unban)
        [[ $# -eq 1 ]] ||
            fatal "Usage: asa unban <player-id>"

        rcon "UnBanPlayer $1"
        ;;

    exit-server)
        printf 'Requesting world save...\n'
        rcon "SaveWorld"

        printf 'Requesting server exit...\n'
        rcon "DoExit"
        ;;

    raw)
        require_arguments "raw" "$@"
        rcon "$*"
        ;;

    help | -h | --help | "")
        usage
        ;;

    *)
        printf 'Unknown command: %s\n\n' "${command_name}" >&2
        usage >&2
        exit 1
        ;;
esac