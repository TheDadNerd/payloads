# Wardrive Automated

Automatically enables wardrive mode when a GPS device is plugged in.

## Disclaimer
This payload is experimental and a work in progress. I am waiting for Hak5
alert-payload documentation to fully implement and validate this workflow.

## Overview
This payload installs a USB hotplug trigger, detects GPS devices, configures
the GPS device, restarts `gpsd`, and starts Wigle logging.

## Requirements
- Hak5 WiFi Pineapple Pager
- USB GPS receiver (ttyACM* or ttyUSB*)

## Installation
1) Copy the `wardrive_automated` folder to `/root/payloads/alerts/`.
2) Run the payload once to auto-install `/etc/hotplug.d/usb/99-wardrive-automated`.

## Usage
1) Plug in a GPS device.
2) The hotplug trigger will launch the payload automatically.

## Configuration
- The GPS device is configured with `GPS_CONFIGURE` at 9600 baud.
- `gpsd` is restarted after configuration.

## What It Does
- Detects GPS devices under `/dev/ttyACM*` and `/dev/ttyUSB*`
- Configures the GPS device via `GPS_CONFIGURE`
- Restarts `gpsd` to apply the configuration
- Starts Wigle logging
- The hotplug trigger calls the payload with the detected device path

## Uninstall
- Remove `/etc/hotplug.d/usb/99-wardrive-automated`.
- Delete `/root/payloads/alerts/wardrive_automated/`.

## Troubleshooting
- If no GPS devices are detected, try re-plugging the GPS after boot completes.
- If Wigle logging fails to start, confirm the Pager firmware supports WIGLE_START.

## Changelog
- 1.0: Initial automated wardrive payload
