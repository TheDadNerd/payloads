#!/bin/bash
# Title: Client WiFi Picker
# Author: TheDadNerd
# Description: Switches client mode WiFi using a selected profile
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

# Load or collect saved profiles.
config_count=$(get_payload_config "count")
if [[ "$config_count" =~ ^[0-9]+$ ]] && [[ "$config_count" -ge 1 ]]; then
    # Allow the user to reset saved profiles.
    RESP=$(CONFIRMATION_DIALOG "Reconfigure saved WiFi profiles?")
    case "$RESP" in
        $DUCKYSCRIPT_USER_CONFIRMED)
            for idx in $(seq 1 "$config_count"); do
                PAYLOAD_DEL_CONFIG "$PAYLOAD_NAME" "ssid_$idx"
                PAYLOAD_DEL_CONFIG "$PAYLOAD_NAME" "pass_$idx"
                PAYLOAD_DEL_CONFIG "$PAYLOAD_NAME" "enc_$idx"
            done
            PAYLOAD_DEL_CONFIG "$PAYLOAD_NAME" "count"
            config_count=0
            ;;
        $DUCKYSCRIPT_USER_DENIED)
            ;;
        *)
            exit 1
            ;;
    esac
fi

if ! [[ "$config_count" =~ ^[0-9]+$ ]] || [[ "$config_count" -lt 1 ]]; then
    LOG "No saved WiFi profiles found."
    RESP=$(CONFIRMATION_DIALOG "Do you want to enter your WiFi networks now?")
    case "$RESP" in
        $DUCKYSCRIPT_USER_DENIED)
            LOG "No networks saved. Re-run the payload to configure."
            exit 1
            ;;
        $DUCKYSCRIPT_USER_CONFIRMED)
            ;;
        *)
            exit 1
            ;;
    esac

    LOG "Entering WiFi profiles..."
    SSIDS=()
    PASSWORDS=()
    ENCRYPTIONS=()

    # Collect one or more networks from the user.
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
        ERROR_DIALOG "No networks entered. Re-run the payload to configure."
        exit 1
    fi

    # Persist profiles using payload config storage.
    for i in "${!SSIDS[@]}"; do
        idx=$((i + 1))
        set_payload_config "ssid_$idx" "${SSIDS[$i]}"
        set_payload_config "pass_$idx" "${PASSWORDS[$i]}"
        set_payload_config "enc_$idx" "${ENCRYPTIONS[$i]}"
    done
    set_payload_config "count" "${#SSIDS[@]}"
    LOG "Saved ${#SSIDS[@]} WiFi profiles."
fi

# Load configured networks from payload storage.
SSIDS=()
PASSWORDS=()
ENCRYPTIONS=()
config_count=$(get_payload_config "count")
if ! [[ "$config_count" =~ ^[0-9]+$ ]] || [[ "$config_count" -lt 1 ]]; then
    ERROR_DIALOG "No saved WiFi profiles. Re-run the payload to configure."
    exit 1
fi
for idx in $(seq 1 "$config_count"); do
    ssid=$(get_payload_config "ssid_$idx")
    password=$(get_payload_config "pass_$idx")
    encryption=$(get_payload_config "enc_$idx")
    SSIDS+=("$ssid")
    PASSWORDS+=("$password")
    ENCRYPTIONS+=("${encryption:-psk2}")
done

# Validate config arrays.
if [[ "${#SSIDS[@]}" -eq 0 ]]; then
    ERROR_DIALOG "No SSIDs configured. Re-run the payload to configure."
    exit 1
fi

if [[ "${#SSIDS[@]}" -ne "${#PASSWORDS[@]}" ]]; then
    ERROR_DIALOG "SSID/PASSWORD list mismatch. Ensure arrays are the same length."
    exit 1
fi

if [[ "${#ENCRYPTIONS[@]}" -ne 0 && "${#ENCRYPTIONS[@]}" -ne "${#SSIDS[@]}" ]]; then
    ERROR_DIALOG "SSID/ENCRYPTION list mismatch. Ensure arrays are the same length."
    exit 1
fi

# Build menu text for the selection dialog.
MENU="Select a client WiFi profile:\n"
for i in "${!SSIDS[@]}"; do
    MENU+="\n$((i + 1))) ${SSIDS[$i]}"
done

LOG "Building network list..."
LOG "$MENU"
LOG "Waiting for user to review list..."
WAIT_FOR_BUTTON_PRESS

LOG "Awaiting user selection..."
choice=$(NUMBER_PICKER "Pick a network (1-${#SSIDS[@]})" 1)
handle_picker_status $?

# Validate selection and map to profile index.
if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#SSIDS[@]} )); then
    ERROR_DIALOG "Invalid selection: $choice"
    exit 1
fi

index=$((choice - 1))
ssid="${SSIDS[$index]}"
password="${PASSWORDS[$index]}"
encryption="${ENCRYPTIONS[$index]:-psk2}"

if [[ -z "$password" || "$encryption" == "none" ]]; then
    encryption="none"
fi

# Confirm before applying changes.
confirm=$(CONFIRMATION_DIALOG "Connect to \"$ssid\" now?")
case "$confirm" in
    "$DUCKYSCRIPT_USER_DENIED")
        LOG "Operation cancelled by user."
        exit 0
        ;;
    "$DUCKYSCRIPT_USER_CONFIRMED")
        ;;
    1) ;; # fallback confirmation
    *) exit 0 ;;
esac

# =============================================================================
# APPLY WIRELESS CONFIGURATION
# =============================================================================

LOG "Preparing client mode configuration..."
# Ensure the spinner stops even if the script errors out.
SPINNER_ID=""
cleanup_spinner() {
    if [[ -n "$SPINNER_ID" ]]; then
        STOP_SPINNER "$SPINNER_ID"
    fi
}
trap cleanup_spinner EXIT
# Use the Pager client-mode interface section.
CLIENT_SECTION="wlan0cli"

# Apply SSID and security settings.
LOG "Updating client profile: $ssid"
uci set wireless."$CLIENT_SECTION".ssid="$ssid"
uci set wireless."$CLIENT_SECTION".encryption="$encryption"
uci set wireless."$CLIENT_SECTION".disabled="0"

if [[ "$encryption" == "none" ]]; then
    uci -q delete wireless."$CLIENT_SECTION".key
else
    uci set wireless."$CLIENT_SECTION".key="$password"
fi

uci commit wireless

LOG "Applying WiFi settings..."
SPINNER_ID=$(START_SPINNER "Applying WiFi settings")
if ! timeout 20s wifi reload; then
    LOG "WiFi reload timed out after 20 seconds."
fi

STOP_SPINNER "$SPINNER_ID"
LOG "WiFi settings applied for $ssid"
