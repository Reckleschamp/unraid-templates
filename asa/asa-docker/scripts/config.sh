#!/usr/bin/env 
initialize_config_file() {
    local filename="$1"
    local source_file="${ASA_CONFIG_DIR}/${filename}"
    local config_file="${CONFIG_DIR}/${filename}"

    # Keep an existing non-empty master configuration.
    if [[ -s "${config_file}" ]]; then
        return
    fi

    # Replace an existing zero-byte file.
    if [[ -f "${config_file}" ]]; then
        warn "${config_file} is empty and will be initialized."
    fi

    # Import an existing non-empty ASA-generated configuration when available.
    if [[ -s "${source_file}" ]]; then
        log "Initializing ${filename} from ASA's existing configuration."

        cp \
            --preserve=mode,timestamps \
            "${source_file}" \
            "${config_file}"

        return
    fi

    log "Creating initial ${config_file}."

    case "${filename}" in
        Game.ini)
            cat >"${config_file}" <<'EOF'
[/Script/ShooterGame.ShooterGameMode]
EOF
            ;;

        GameUserSettings.ini)
            cat >"${config_file}" <<EOF
[ServerSettings]
RCONEnabled=True
RCONPort=${RCON_PORT}

[/Script/Engine.GameSession]
MaxPlayers=${MAX_PLAYERS}
EOF
            ;;

        Engine.ini)
            # Engine.ini is allowed to be empty.
            : >"${config_file}"
            ;;

        *)
            : >"${config_file}"
            ;;
    esac
}


initialize_config() {
    log "Checking master configuration files in ${CONFIG_DIR}."

    initialize_config_file "Game.ini"
    initialize_config_file "GameUserSettings.ini"
    initialize_config_file "Engine.ini"
}

copy_config_to_server() {
    log "Copying master INI files into ASA's WindowsServer directory."

    local filename

    for filename in \
        Game.ini \
        GameUserSettings.ini \
        Engine.ini; do

        require_file "${CONFIG_DIR}/${filename}"

        cp \
            "${CONFIG_DIR}/${filename}" \
            "${ASA_CONFIG_DIR}/${filename}"
    done
}