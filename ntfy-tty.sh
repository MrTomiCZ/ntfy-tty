#!/usr/bin/env bash
# > Author: JPman
# > Email: admin@jpman.eu
# > Github: https://github.com/jakub-petrovic/ntfy-tty
# > License: GNU AGPLv3
# > Copyright 2026 Jakub Petrovič

# Dependency checks
NTFY_DEPS=('curl' 'date' 'mkdir' 'readlink' 'cmp' 'diff' 'less' 'cp' 'chmod' 'mv' 'rm' 'tr')

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
LOG_DIR_LOCATION=$HOME/.ntfy-tty/logs # removed trailing slash cuz the path would be /home/<user>/.ntfy-tty/logs//...
LOG_FILE_NAME="ntfy-tty_$(date +'%Y-%m-%d_%H-%M-%S').log"
FULL_LOG_PATH="$LOG_DIR_LOCATION/$LOG_FILE_NAME"
NTFY_SOURCE="https://github.com/jakub-petrovic/ntfy-tty/raw/refs/heads/main/ntfy-tty.sh"
NTFY_UPDATE="auto"

MESSAGE=""
NTFY_TOKEN=""
NTFY_USERNAME=""
NTFY_PASSWORD=""
NTFY_TOPIC=""
NTFY_SERVER="https://ntfy.sh/"
NTFY_MODE="send"

# Functions
log() {
    mkdir -p "$(dirname "$FULL_LOG_PATH")"
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
        [[ -v config[UPDATE] ]] && NTFY_UPDATE="${config[UPDATE]}"
        [[ -v config[MODE] ]] && NTFY_MODE="${config[MODE]}"
        [[ -v config[RCVMODE] ]] && NTFY_RCV_MODE="${config[RCVMODE]}"
    fi
}

send_ntfy() {
    # check if the ntfy server ends with a slash, if yes continue, if no append it
    [[ ! "$NTFY_SERVER" == */ ]] && NTFY_SERVER="$NTFY_SERVER/"

    if [[ "$NTFY_MODE" == "receive" || "$NTFY_MODE" == "get" ]]; then
        #echo "will be implemented"
        if [[ -n "$NTFY_TOKEN" ]]; then
            # Token
            NTFY_COMMAND=('token' 'curl -H '"Authorization: Bearer $NTFY_TOKEN" -d "$MESSAGE" "${NTFY_SERVER}${NTFY_TOPIC}"'')
        elif [[ -n "$NTFY_USERNAME" && -n "$NTFY_PASSWORD" ]]; then
            # User & pass
            curl -u "$NTFY_USERNAME:$NTFY_PASSWORD" -d "$MESSAGE" "${NTFY_SERVER}${NTFY_TOPIC}"
        else
            # No auth
            curl -d "$MESSAGE" "${NTFY_SERVER}${NTFY_TOPIC}"
        fi
        
        if [[ "$NTFY_RCV_MODE" == "raw" || "$NTFY_RCV_MODE" == "" ]]; then
            curl -H "Authorization: Bearer $NTFY_TOKEN" -d "$MESSAGE" "${NTFY_SERVER}${NTFY_TOPIC}/raw" # only supports token auth
        elif [[ "$NTFY_RCV_MODE" == "json" ]]; then
            curl -H "Authorization: Bearer $NTFY_TOKEN" -d "$MESSAGE" "${NTFY_SERVER}${NTFY_TOPIC}/json" # only supports token auth
        elif [[ "$NTFY_RCV_MODE" == "sse" ]]; then
            curl -H "Authorization: Bearer $NTFY_TOKEN" -d "$MESSAGE" "${NTFY_SERVER}${NTFY_TOPIC}/sse" # only supports token auth
        else
            echo "unknown receive mode" >&2
        fi
    elif [[ "$NTFY_MODE" == "send" || "$NTFY_MODE" == "put" ]]; then
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
    else
        echo "Unknown mode provided" >&2
        exit 1 # exit with a non-success exit code cause we couldnt send and would rather exit than break stuff
    fi
}

updater() {
    # Updater function

    # don't update
    if [[ "$NTFY_UPDATE" == "never" ]]; then return 0; fi

    TEMPFILE="${TMPDIR:-/tmp}/ntfytty.sh"
    CURRFILE="$(readlink -f "$0")"
    curl -fsSL "$NTFY_SOURCE" -o "$TEMPFILE"
    if [[ ! -s "$TEMPFILE" ]]; then
        echo "Failed to download update" >&2
    fi
    if cmp -s "$TEMPFILE" "$CURRFILE"; then
        rm "$TEMPFILE"
    else
        # update
        if [[ "$NTFY_UPDATE" == "always" ]]; then update "$@"; return 0
        # ask user
        elif [[ "$NTFY_UPDATE" == "auto" || "$NTFY_UPDATE" == "ask" ]]; then
            diff --color=always "$TEMPFILE" "$CURRFILE" | less -R

            while true; do
                read -p "Update? [Yn] " answer

                case "$answer" in
                    ""|[Yy])
                        update "$@"
                        break
                        ;;
                    [Nn])
                        echo "Not updating"
                        rm "$TEMPFILE"
                        break
                        ;;
                    *)
                        echo "invalid option"
                        ;;
                esac
            done
        # something other
        else
            echo "cannot figure out what update mode to use" >&2
            echo "valid are: ask, auto, always, never" >&2
            echo "ask is an alias for auto" >&2
            # not fatal; continue
        fi
    fi
}
update() {
    # update function for purposes above
    echo "Updating"
    cp "$TEMPFILE" "$CURRFILE.tmp" &&
    chmod +x "$CURRFILE.tmp" &&
    mv "$CURRFILE.tmp" "$CURRFILE" &&
    rm "$TEMPFILE" &&
    exec "$CURRFILE" "$@"
}

show_help() {
    local PRINTF_PADDING_PATTERN="%-15s %5s\n"
    echo "ntfy-tty"
    echo "Simple utility to send notifications to ntfy"
    echo ""
    echo "Source:   $NTFY_SOURCE"
    echo "Author:   JPman (admin@jpman.eu)"
    echo "License:  GNU AGPLv3"
    echo "Copyright 2026 Jakub Petrovič"
    echo ""
    echo "Syntax:"
    printf "$PRINTF_PADDING_PATTERN" "-m --message" "Message - Message to send to the ntfy server"
    printf "$PRINTF_PADDING_PATTERN" "-h --help -?" "Help - this help message & exit"
    printf "$PRINTF_PADDING_PATTERN" "-t --topic" "Topic - Topic to which send the message on the ntfy server"
    printf "$PRINTF_PADDING_PATTERN" "-c --config" "Config - Config file from which to load config"
    printf "$PRINTF_PADDING_PATTERN" "-s --server" "Server - Server to which send the ntfy request"
    printf "$PRINTF_PADDING_PATTERN" "-u --username" "Username - Username with which to authenticate to the ntfy server (use in combination with -p)"
    printf "$PRINTF_PADDING_PATTERN" "-p --password" "Password - Password with which to authenticate to the ntfy server (use in combination with -u)"
    printf "$PRINTF_PADDING_PATTERN" "-a --token" "Token - Token with which to authenticate to the ntfy server (has priority over -u & -p)"
    printf "$PRINTF_PADDING_PATTERN" "-l --log" "Log file - by default this is stored in $LOG_DIR_LOCATION and smth with the date idrk (assuming -l wasn't specified)"
    printf "$PRINTF_PADDING_PATTERN" "-d --update" "Update - forces an update (does not ask the user for permission to update)"
    printf "$PRINTF_PADDING_PATTERN" "-n --no-update" "No Update - forces to not update (does not ask the user to update; doesn't update lol)"
    printf "$PRINTF_PADDING_PATTERN" "-r --receive" "Receive - Receives from the server URL specified (topic & server, -m sends a message to the URL before connecting)"
    printf "$PRINTF_PADDING_PATTERN" "-S --send" "Send - Sends a message to the server URL specified, this is the default option unless specified otherwise by the config"
    printf "$PRINTF_PADDING_PATTERN" "-R --receive-mode -rm" "Receive mode - can be 'json', 'raw' and 'sse'. By default this is 'raw'"
}

# Load the config
load_config

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -m|--message)
            MESSAGE="$2"
            shift
            ;;
        -h|--help|"-?")
            show_help
            #break
            exit 0 # i think you meant to exit
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
        -a|--token)
            NTFY_TOKEN="$2"
            shift
            ;;
        -l|--log)
            FULL_LOG_PATH="$2"
            shift
            ;;
        -d|--update)
            NTFY_UPDATE="always"
            ;;
        -n|--no-update)
            NTFY_UPDATE="never"
            ;;
        -r|--receive)
            NTFY_MODE="receive"
            ;;
        -S|--send)
            NTFY_MODE="send"
            ;;
        -R|--receive-mode|-rm)
            NTFY_RCV_MODE="$2"
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

# Updater
updater "$@"

# Debugging
trap 'log "RUNNING: $BASH_COMMAND"' DEBUG
trap 'log "ERROR: Command failed on line $LINENO with exit code $?"' ERR

# Main
send_ntfy
