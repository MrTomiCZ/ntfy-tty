#!/usr/bin/env bash
# > Author: JPman
# > Email: admin@jpman.eu
# > Github: https://github.com/jakub-petrovic/ntfy-tty
# > License: GNU AGPLv3
# > Copyright 2026 Jakub Petrovič

# Dependency checks
NTFY_DEPS=('curl' 'date' 'mkdir' 'echo' 'trap' 'bash')

toolErr() {
    echo "$1 doesn't exist" >&2
    echo "please install or edit source" >&2
    echo "to use a tool of your choice" >&2
    exit 1
}

# Check for bash version
if (( BASH_VERSINFO[0] >= 4 )); then
    :
else
    echo "bash 4.0 or higher is required to run this script" >&2
    exit 1
fi

# Check for dependencies
for item in "${NTFY_DEPS[@]}"; do
    if command -v "$item" >/dev/null 2>&1; then
        :
    else
        toolErr "$item"
    fi
done

set -T
# Global variables
CONFIG_LOCATION=$HOME/.ntfy-tty/config.conf
LOG_DIR_LOCATION=$HOME/.ntfy-tty/logs/
LOG_FILE_NAME="ntfy-tty_$(date +'%Y-%m-%d_%H-%M-%S').log"
FULL_LOG_PATH="$LOG_DIR_LOCATION/$LOG_FILE_NAME"

MESSAGE=""
NTFY_TOKEN=""
NTFY_USERNAME=""
NTFY_PASSWORD=""
NTFY_TOPIC=""
NTFY_SERVER="https://ntfy.sh/"

# Functions
log() {
    mkdir -p "$(dirname $FULL_LOG_PATH)"
    echo "$1" >> "$FULL_LOG_PATH"
}

load_config() {
    if [[ -f "$CONFIG_LOCATION" ]]; then
        declare -A config
        while IFS='=' read -r key value || [ -n "$key" ]; do
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            config["$key"]="$(echo "$value" | tr -d '\r')"
        done < "$CONFIG_LOCATION"
        
        [[ -v config[LOG_PATH] ]] && FULL_LOG_PATH="${config[LOG_PATH]}"        
        [[ -v config[TOKEN] ]] && NTFY_TOKEN="${config[TOKEN]}"
        [[ -v config[PASSWORD] ]] && NTFY_PASSWORD="${config[PASSWORD]}"
        [[ -v config[USERNAME] ]] && NTFY_USERNAME="${config[USERNAME]}"
        [[ -v config[SERVER] ]] && NTFY_SERVER="${config[SERVER]}"
        [[ -v config[TOPIC] ]] && NTFY_TOPIC="${config[TOPIC]}"
    fi
}

send_ntfy() {
    # echo "$NTFY_TOKEN $NTFY_SERVER $NTFY_TOPIC $NTFY_USERNAME $NTFY_PASSWORD $MESSAGE"
    # Auth methods
    if [[ -n "$NTFY_TOKEN" ]]; then
        # Token
        curl -H "Authorization: Bearer $NTFY_TOKEN" -d "$MESSAGE" "${NTFY_SERVER}${NTFY_TOPIC}"
    elif [[ -n "$NTFY_USERNAME" && -n "$NTFY_PASSWORD" ]]; then
        # User & pass
        curl -u "$NTFY_USERNAME:$NTFY_PASSWORD" -d "$MESSAGE" "${NTFY_SERVER}${NTFY_TOPIC}"
    else
        # No auth
        curl -d "$MESSAGE" "${NTFY_SERVER}${NTFY_TOPIC}"
    fi
}

# 

# Load the config
load_config

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -m|--message) 
            MESSAGE="$2"
            shift 
            ;;
        -h|--help)
            show_help
            break
            ;;
        -t|--topic)
            NTFY_TOPIC="$2"
            shift
            ;;
        -c|--config)
            CONFIG_LOCATION="$2"
            load_config
            shift
            ;;
        -s|--server)
            NTFY_SERVER="$2"
            shift
            ;; 
        -u|--username)
            NTFY_USERNAME="$2"
            shift
            ;;
        -p|--password)
            NTFY_PASSWORD="$2"
            shift
            ;;
        --token)
            NTFY_TOKEN="$2"
            shift
            ;;
        -l|--log)
            FULL_LOG_PATH="$2"
            shift
            ;;
        *) 
            echo "Unknown parameter passed: $1"
            show_help
            exit 1 
            ;;
    esac
    shift
done

# Debugging
trap 'log "RUNNING: $BASH_COMMAND"' DEBUG
trap 'log "ERROR: Command failed on line $LINENO with exit code $?"' ERR

# Main
send_ntfy
