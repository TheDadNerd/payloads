#!/bin/bash
# Title: Switch Client WiFi
# Author: TheDadNerd
# Description: Switches client mode WiFi using a selected profile
# Version: 1.0
# Category: general

# =============================================================================
# CONFIGURATION: HARD-CODED NETWORKS
# =============================================================================

SSIDS=(
    "Office-WiFi"
    "Lab-Network"
    "Mobile-Hotspot"
)

PASSWORDS=(
    "ChangeMe123!"
    "ReplaceThisPassword"
    "HotspotPass"
)

# Optional: override per-network encryption (default psk2). Use "none" for open.
ENCRYPTIONS=(
    "psk2"
    "psk2"
    "psk2"
)

# =============================================================================
# INTERNALS
# =============================================================================

handle_picker_status() {
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

if [[ "${#SSIDS[@]}" -eq 0 ]]; then
    ERROR_DIALOG "No SSIDs configured. Edit payload.sh to add networks."
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

MENU="Select a client WiFi profile:\n"
for i in "${!SSIDS[@]}"; do
    MENU+="\n$((i + 1))) ${SSIDS[$i]}"
done

LOG "Building network list..."
ALERT "$MENU"

LOG "Awaiting user selection..."
choice=$(NUMBER_PICKER "Pick a network (1-${#SSIDS[@]})" 1)
handle_picker_status $?

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
CLIENT_SECTION=$(uci show wireless 2>/dev/null | awk -F'[.=]' '
/=wifi-iface/ {section=$2}
/mode='\''sta'\''/ {print section}
' | head -n 1)

if [[ -z "$CLIENT_SECTION" ]]; then
    CLIENT_SECTION="wlan0cli"
    LOG "Client section not found, defaulting to $CLIENT_SECTION"
fi

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
id=$(START_SPINNER "Applying WiFi settings")
wifi reload

# =============================================================================
# WAIT FOR IP ASSIGNMENT
# =============================================================================

CLIENT_IFACE=$(uci -q get wireless."$CLIENT_SECTION".ifname)
if [[ -z "$CLIENT_IFACE" ]]; then
    CLIENT_IFACE="wlan0cli"
    LOG "Client interface not found, defaulting to $CLIENT_IFACE"
fi

CLIENT_IP=""
for _ in $(seq 1 10); do
    LOG "Waiting for IP on $CLIENT_IFACE..."
    CLIENT_IP=$(ip -4 addr show "$CLIENT_IFACE" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n 1)
    if [[ -n "$CLIENT_IP" ]]; then
        break
    fi
    sleep 2
done

STOP_SPINNER $id

if [[ -n "$CLIENT_IP" ]]; then
    LOG "Connected: $ssid"
    LOG "Client IP: $CLIENT_IP"
    ALERT "Connected to $ssid\nClient IP: $CLIENT_IP"
else
    ERROR_DIALOG "No IP detected on $CLIENT_IFACE. Check WiFi credentials or coverage."
    exit 1
fi
