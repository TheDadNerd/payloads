#!/bin/bash
# Title: Switch Client WiFi
# Author: TheDadNerd
# Description: Switches client mode WiFi using a selected profile
# Version: 1.0
# Category: general

# =============================================================================
# INTERNALS: helper functions and configuration bootstrap
# =============================================================================

handle_picker_status() {
    # Normalizes DuckyScript dialog exit codes.
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

# Config location on the Pager.
CONFIG_DIR="/root/payloadconfigs/switch_client_wifi"
CONFIG_FILE="$CONFIG_DIR/networks.conf"

# Ensure config directory exists.
if [[ ! -d "$CONFIG_DIR" ]]; then
    mkdir -p "$CONFIG_DIR"
    ALERT "Created $CONFIG_DIR.\nEdit networks.conf before running again."
fi

# Bootstrap config file if missing; optionally prompt for interactive entry.
if [[ ! -f "$CONFIG_FILE" ]]; then
    ALERT "No config found. Creating a new one at:\n$CONFIG_FILE"
    RESP=$(CONFIRMATION_DIALOG "Do you want to enter your WiFi networks now?")
    case "$RESP" in
        $DUCKYSCRIPT_USER_DENIED)
            ALERT "Created $CONFIG_DIR.\nEdit networks.conf before running again."
            cat <<'EOF' >"$CONFIG_FILE"
#!/bin/bash
# WiFi profiles for Switch Client WiFi payload.

SSIDS=(
    "Office-WiFi"
)

PASSWORDS=(
    "ChangeMe123!"
)

# Optional: per-network encryption (default psk2). Use "none" for open.
ENCRYPTIONS=(
    "psk2"
)
EOF
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

        password=$(TEXT_PICKER "Password" "")
        handle_picker_status $?

        SSIDS+=("$ssid")
        PASSWORDS+=("$password")
        if [[ -z "$password" ]]; then
            ENCRYPTIONS+=("none")
        else
            ENCRYPTIONS+=("psk2")
        fi

        RESP=$(CONFIRMATION_DIALOG "Add another network or done?")
        case "$RESP" in
            $DUCKYSCRIPT_USER_CONFIRMED) ;;
            $DUCKYSCRIPT_USER_DENIED) break ;;
            *) break ;;
        esac
    done

    if [[ "${#SSIDS[@]}" -eq 0 ]]; then
        ERROR_DIALOG "No networks entered. Edit $CONFIG_FILE and try again."
        exit 1
    fi

    # Write the config file in a simple bash format for sourcing.
    {
        echo '#!/bin/bash'
        echo '# WiFi profiles for Switch Client WiFi payload.'
        echo
        echo 'SSIDS=('
        for ssid in "${SSIDS[@]}"; do
            printf '    "%s"\n' "$ssid"
        done
        echo ')'
        echo
        echo 'PASSWORDS=('
        for password in "${PASSWORDS[@]}"; do
            printf '    "%s"\n' "$password"
        done
        echo ')'
        echo
        echo '# Optional: per-network encryption (default psk2). Use "none" for open.'
        echo 'ENCRYPTIONS=('
        for enc in "${ENCRYPTIONS[@]}"; do
            printf '    "%s"\n' "$enc"
        done
        echo ')'
    } >"$CONFIG_FILE"

    ALERT "Saved $CONFIG_FILE.\nRe-run the payload to connect."
    exit 0
fi

# Load configured networks.
source "$CONFIG_FILE"

# Validate config arrays.
if [[ "${#SSIDS[@]}" -eq 0 ]]; then
    ERROR_DIALOG "No SSIDs configured. Edit networks.conf to add networks."
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
ALERT "$MENU"

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
# Find the first STA (client mode) wireless section.
CLIENT_SECTION=$(uci show wireless 2>/dev/null | awk -F'[.=]' '
/=wifi-iface/ {section=$2}
/mode='\''sta'\''/ {print section}
' | head -n 1)

if [[ -z "$CLIENT_SECTION" ]]; then
    CLIENT_SECTION="wlan0cli"
    LOG "Client section not found, defaulting to $CLIENT_SECTION"
fi

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
id=$(START_SPINNER "Applying WiFi settings")
wifi reload

# =============================================================================
# WAIT FOR IP ASSIGNMENT
# =============================================================================

# Determine the client interface name and wait for DHCP.
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
