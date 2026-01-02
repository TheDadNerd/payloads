#!/bin/bash
# Title: Client Wifi Picker Configuration
# Author: TheDadNerd
# Description: Configure saved client WiFi profiles
# Version: 1.0
# Category: general

# =============================================================================
# INTERNALS: helpers and config storage
# =============================================================================

handle_picker_status() {
    # Normalize DuckyScript dialog exit codes.
    local status="$1"
    case "$status" in
        "$DUCKYSCRIPT_CANCELLED")
            LOG "User cancelled"
            exit 1
            ;;
        "$DUCKYSCRIPT_REJECTED")
            LOG "Dialog rejected"
            exit 1
            ;;
        "$DUCKYSCRIPT_ERROR")
            ERROR_DIALOG "An error occurred"
            exit 1
            ;;
    esac
}

# Pager CONFIG storage key namespace.
PAYLOAD_NAME="switch_client_wifi"

get_payload_config() {
    # Wrapper for payload config reads.
    PAYLOAD_GET_CONFIG "$PAYLOAD_NAME" "$1" 2>/dev/null
}

set_payload_config() {
    # Wrapper for payload config writes.
    PAYLOAD_SET_CONFIG "$PAYLOAD_NAME" "$1" "$2"
}

# Load profiles from config into arrays.
load_profiles() {
    SSIDS=()
    PASSWORDS=()
    ENCRYPTIONS=()
    local count
    count=$(get_payload_config "count")
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -lt 1 ]]; then
        return 1
    fi
    for idx in $(seq 1 "$count"); do
        SSIDS+=("$(get_payload_config "ssid_$idx")")
        PASSWORDS+=("$(get_payload_config "pass_$idx")")
        ENCRYPTIONS+=("$(get_payload_config "enc_$idx")")
    done
    return 0
}

# Save current arrays back to config storage.
save_profiles() {
    local count
    count=$(get_payload_config "count")
    if [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -ge 1 ]]; then
        for idx in $(seq 1 "$count"); do
            PAYLOAD_DEL_CONFIG "$PAYLOAD_NAME" "ssid_$idx"
            PAYLOAD_DEL_CONFIG "$PAYLOAD_NAME" "pass_$idx"
            PAYLOAD_DEL_CONFIG "$PAYLOAD_NAME" "enc_$idx"
        done
        PAYLOAD_DEL_CONFIG "$PAYLOAD_NAME" "count"
    fi

    if [[ "${#SSIDS[@]}" -eq 0 ]]; then
        return 0
    fi

    for i in "${!SSIDS[@]}"; do
        idx=$((i + 1))
        set_payload_config "ssid_$idx" "${SSIDS[$i]}"
        set_payload_config "pass_$idx" "${PASSWORDS[$i]}"
        set_payload_config "enc_$idx" "${ENCRYPTIONS[$i]}"
    done
    set_payload_config "count" "${#SSIDS[@]}"
}

# =============================================================================
# CONFIGURATION FLOW
# =============================================================================

if load_profiles; then
    LOG "Existing WiFi profiles found."
    ALERT "Config options:\n1) Delete all\n2) Delete one\n3) Add new\n4) Exit"
    WAIT_FOR_BUTTON_PRESS
    action=$(NUMBER_PICKER "Choose option (1-4)" 3)
    handle_picker_status $?
    case "$action" in
        1)
            SSIDS=()
            PASSWORDS=()
            ENCRYPTIONS=()
            ;;
        2)
            while [[ "${#SSIDS[@]}" -gt 0 ]]; do
                MENU="Select a network to delete:\n"
                for i in "${!SSIDS[@]}"; do
                    MENU+="\n$((i + 1))) ${SSIDS[$i]}"
                done
                ALERT "$MENU"
                WAIT_FOR_BUTTON_PRESS
                del_choice=$(NUMBER_PICKER "Delete which (1-${#SSIDS[@]})" 1)
                handle_picker_status $?
                if ! [[ "$del_choice" =~ ^[0-9]+$ ]] || (( del_choice < 1 || del_choice > ${#SSIDS[@]} )); then
                    ERROR_DIALOG "Invalid selection: $del_choice"
                    exit 1
                fi
                del_index=$((del_choice - 1))
                NEW_SSIDS=()
                NEW_PASSWORDS=()
                NEW_ENCRYPTIONS=()
                for i in "${!SSIDS[@]}"; do
                    if [[ "$i" -ne "$del_index" ]]; then
                        NEW_SSIDS+=("${SSIDS[$i]}")
                        NEW_PASSWORDS+=("${PASSWORDS[$i]}")
                        NEW_ENCRYPTIONS+=("${ENCRYPTIONS[$i]}")
                    fi
                done
                SSIDS=("${NEW_SSIDS[@]}")
                PASSWORDS=("${NEW_PASSWORDS[@]}")
                ENCRYPTIONS=("${NEW_ENCRYPTIONS[@]}")

                if [[ "${#SSIDS[@]}" -eq 0 ]]; then
                    LOG "All profiles removed."
                    break
                fi

                RESP=$(CONFIRMATION_DIALOG "Delete another network?")
                case "$RESP" in
                    $DUCKYSCRIPT_USER_CONFIRMED) ;;
                    $DUCKYSCRIPT_USER_DENIED) break ;;
                    *) break ;;
                esac
            done

            save_profiles
            ALERT "Saved ${#SSIDS[@]} remaining profiles."
            exit 0
            ;;
        3)
            ;;
        4)
            exit 0
            ;;
        *)
            ERROR_DIALOG "Invalid selection: $action"
            exit 1
            ;;
    esac
fi

LOG "Entering WiFi profiles..."

while :; do
    ssid=$(TEXT_PICKER "SSID" "")
    handle_picker_status $?
    if [[ -z "$ssid" ]]; then
        ERROR_DIALOG "SSID cannot be empty."
        continue
    fi

    LOG "Selecting encryption for $ssid..."
    ALERT "Select encryption:\n1) Open\n2) WPA2 PSK\n3) WPA2 PSK/WPA3 SAE\n4) WPA3 SAE (personal)"
    WAIT_FOR_BUTTON_PRESS
    enc_choice=$(NUMBER_PICKER "Encryption (1-4)" 2)
    handle_picker_status $?
    case "$enc_choice" in
        1) encryption="none" ;;
        2) encryption="psk2" ;;
        3) encryption="sae-mixed" ;;
        4) encryption="sae" ;;
        *) ERROR_DIALOG "Invalid encryption selection: $enc_choice"; continue ;;
    esac

    password=""
    if [[ "$encryption" != "none" ]]; then
        password=$(TEXT_PICKER "Password" "")
        handle_picker_status $?
    fi

    SSIDS+=("$ssid")
    PASSWORDS+=("$password")
    ENCRYPTIONS+=("$encryption")

    RESP=$(CONFIRMATION_DIALOG "Add another network?")
    case "$RESP" in
        $DUCKYSCRIPT_USER_CONFIRMED) ;;
        $DUCKYSCRIPT_USER_DENIED) break ;;
        *) break ;;
    esac
done

if [[ "${#SSIDS[@]}" -eq 0 ]]; then
    ERROR_DIALOG "No networks entered. Run the configuration payload again."
    exit 1
fi

save_profiles
ALERT "Saved ${#SSIDS[@]} WiFi profiles.\nRun Client Wifi Picker to connect."
