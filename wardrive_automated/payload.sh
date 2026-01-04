#!/bin/bash
# Title: Wardrive Automated
# Author: TheDadNerd
# Description: Detects GPS devices, updates gpsd config, restarts gpsd, and starts Wigle
# Version: 1.0
# Category: general

# =============================================================================
# INTERNALS: helpers and device detection
# =============================================================================

handle_picker_status() {
    # Normalize DuckyScript dialog exit codes to consistent behavior.
    # This keeps UI exits predictable even if different dialogs are used.
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

collect_gps_devices() {
    # Build a de-duplicated list of possible GPS serial devices.
    # Pager USB GPS modules commonly show up as ttyACM* or ttyUSB*.
    local candidates=()
    local seen=()
    local dev
    for dev in /dev/ttyACM* /dev/ttyUSB*; do
        [[ -c "$dev" ]] || continue
        # Avoid duplicate entries if globbing yields repeats.
        local already=0
        for existing in "${seen[@]}"; do
            if [[ "$existing" == "$dev" ]]; then
                already=1
                break
            fi
        done
        if [[ "$already" -eq 0 ]]; then
            # Track the device once and return it to the caller.
            candidates+=("$dev")
            seen+=("$dev")
        fi
    done
    echo "${candidates[@]}"
}

pick_gps_device() {
    # If multiple devices are found, prompt the user to pick the correct one.
    # If only one device exists, use it without prompting.
    local devices=("$@")
    if [[ "${#devices[@]}" -eq 1 ]]; then
        echo "${devices[0]}"
        return 0
    fi

    # Build a numbered menu list for the Pager dialog prompt.
    MENU="Multiple GPS devices found:\n"
    for i in "${!devices[@]}"; do
        MENU+="\n$((i + 1))) ${devices[$i]}"
    done

    # Show the menu and ensure the dialog succeeded.
    ack=$(PROMPT "$MENU" "")
    handle_picker_status $?

    # Collect the user's numeric selection with bounds.
    choice=$(NUMBER_PICKER "Select GPS device (1-${#devices[@]})" 1)
    handle_picker_status $?

    # Validate selection and convert to zero-based index.
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#devices[@]} )); then
        ERROR_DIALOG "Invalid selection: $choice"
        exit 1
    fi

    echo "${devices[$((choice - 1))]}"
}

# =============================================================================
# MAIN FLOW
# =============================================================================

HOTPLUG_TARGET="/etc/hotplug.d/usb/99-wardrive-automated"

# Ensure the hotplug trigger exists so GPS insertion auto-runs this payload.
if [[ ! -f "$HOTPLUG_TARGET" ]]; then
    LOG "Installing hotplug trigger..."
    cat >"$HOTPLUG_TARGET" <<'EOF'
#!/bin/sh
# Hotplug trigger: start Wardrive Automated on GPS serial add.

case "$DEVNAME" in
  ttyUSB*|ttyACM*)
    ;;
  *)
    exit 0
    ;;
esac

[ "$ACTION" = "add" ] || exit 0

DEVICE="/dev/$DEVNAME"
[ -c "$DEVICE" ] || exit 0

logger -t wardrive_automated "GPS device detected: $DEVICE"
/root/payloads/alerts/wardrive_automated/payload.sh "$DEVICE" >/dev/null 2>&1 &
EOF
    chmod +x "$HOTPLUG_TARGET"
fi

LOG "Detecting GPS devices..."

# Optional device path override (used by hotplug add trigger).
provided_device="$1"

# Prefer a provided device path when present and valid, otherwise auto-detect.
selected_device=""
if [[ -n "$provided_device" && -c "$provided_device" ]]; then
    selected_device="$provided_device"
    LOG "Using provided GPS device: $selected_device"
else
    # Prefer the existing configured device if it is still present.
    configured_device="$(uci -q get gpsd.core.device 2>/dev/null)"
    # Scan for attached GPS devices on common serial paths.
    devices=($(collect_gps_devices))

    # Determine which device should be used this run.
    if [[ -n "$configured_device" && -c "$configured_device" ]]; then
        # Keep the stored device when it is still valid.
        selected_device="$configured_device"
        LOG "Using configured GPS device: $selected_device"
    else
        # If no stored device is valid, require detection or user choice.
        if [[ "${#devices[@]}" -eq 0 ]]; then
            ERROR_DIALOG "No GPS devices found. Check your USB GPS and try again."
            exit 1
        fi
        # Ask the user which device to use when multiple are present.
        selected_device="$(pick_gps_device "${devices[@]}")"
    fi
fi

LOG "Applying GPS device configuration..."
# Enable gpsd and set the selected device path.
uci -q set gpsd.core.enabled="1"
uci -q set gpsd.core.device="$selected_device"
uci -q commit gpsd

# Set the serial baud rate explicitly before restarting gpsd.
LOG "Setting GPS device baud rate to 9600..."
# Pager includes stty; no non-Pager fallback logic is needed.
stty -F "$selected_device" 9600 2>/dev/null || true

LOG "Restarting gpsd..."
# Pager uses OpenWrt init.d; restart gpsd directly.
/etc/init.d/gpsd restart

# Enable Wigle logging now that GPS is configured (no uploads are performed).
LOG "Enabling Wigle logging..."
wigle_file="$(WIGLE_START 2>/dev/null)"
if [[ $? -ne 0 ]]; then
    ERROR_DIALOG "Failed to start Wigle logging."
    exit 1
fi
if [[ -n "$wigle_file" ]]; then
    LOG "Wigle log started: $wigle_file"
fi

# Final user-facing confirmation.
ALERT "GPS device set to:\n$selected_device\n\ngpsd restarted.\nWigle logging started."
