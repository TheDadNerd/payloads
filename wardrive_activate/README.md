# Wardrive Activate

Manually enables wardrive mode on the WiFi Pineapple Pager.

## Overview
This payload activates wardrive mode when run. It detects GPS devices on the
WiFi Pineapple Pager, configures the GPS device, restarts `gpsd`, and starts
Wigle logging.

## Requirements
- Hak5 WiFi Pineapple Pager
- USB GPS receiver (ttyACM* or ttyUSB*)

## Installation
1) Copy the `wardrive_activate` folder to `/root/payloads/`.

## Usage
1) Run the payload from the Pager UI.
2) Select a GPS device if prompted.

## Configuration
- The GPS device is configured with `GPS_CONFIGURE` at 9600 baud.
- `gpsd` is restarted after configuration.

## What It Does
- Detects GPS devices under `/dev/ttyACM*` and `/dev/ttyUSB*`
- Prompts for device selection when multiple devices are present
- Configures the GPS device via `GPS_CONFIGURE`
- Restarts `gpsd` to apply the configuration
- Starts Wigle logging

## Uninstall
- Delete `/root/payloads/wardrive_activate/`.

## Troubleshooting
- If no GPS devices are detected, confirm the GPS is plugged in after boot.
- If no location data appears, allow extra time for GPS lock.

## Changelog
- 1.0: Initial manual wardrive payload
