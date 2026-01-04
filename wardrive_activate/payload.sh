#!/bin/bash
# Title: Wardrive Activate
# Author: TheDadNerd
# Description: Detects GPS devices, configures GPS, and starts Wigle
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
    # Use GPS_LIST output to build a list of USB serial GPS devices.
    # Filter to ttyACM* and ttyUSB* since those are typical GPS device nodes.
    local candidates=()
    local seen=()
    local dev
    local list_output

    list_output="$(GPS_LIST 2>/dev/null)"
    for dev in $(echo "$list_output" | tr ' ' '\n' | grep -E '^/dev/tty(ACM|USB)[0-9]+$' 2>/dev/null); do
        # Avoid duplicate entries in case GPS_LIST returns repeats.
        local already=0
        for existing in "${seen[@]}"; do
            if [[ "$existing" == "$dev" ]]; then
                already=1
                break
            fi
        done
        if [[ "$already" -eq 0 ]]; then
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

LOG "Detecting GPS devices..."

# Optional device path override from the caller (manual runs can pass a device).
provided_device="$1"

# Prefer a provided device path when present and valid, otherwise auto-detect.
selected_device=""
if [[ -n "$provided_device" && -c "$provided_device" ]]; then
    selected_device="$provided_device"
    LOG "Using provided GPS device: $selected_device"
else
    # Prefer the existing configured device from gpsd UCI if it is still present.
    configured_device="$(uci -q get gpsd.core.device 2>/dev/null)"
    # Scan for attached GPS devices using GPS_LIST.
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

LOG "Configuring GPS device..."
# Use DuckyScript GPS_CONFIGURE to set the device and baud rate.
GPS_CONFIGURE "$selected_device" 9600 >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    ERROR_DIALOG "Failed to configure GPS device."
    exit 1
fi

LOG "Restarting gpsd..."
# Restart gpsd to apply the new GPS device configuration.
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
ALERT "GPS device set to:\n$selected_device\n\ngpsd configured.\nWigle logging started."
