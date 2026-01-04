# Client WiFi Picker Configuration

Configure saved client WiFi profiles for the Client WiFi Picker payload.

## Overview
This payload collects SSIDs, encryption types, and passwords, and stores them
using the Pager CONFIG commands for later selection.

## Requirements
- Hak5 WiFi Pineapple Pager

## Installation
1) Copy `switch_client_wifi_configuration` and `switch_client_wifi` to `/root/payloads/user/general/`.

## Usage
1) Run `switch_client_wifi_configuration`.
2) Add, delete, or view saved WiFi profiles.
3) Run `switch_client_wifi` to connect.

## Configuration
- Profiles are stored using `PAYLOAD_SET_CONFIG` under `switch_client_wifi`.
- Supported encryptions: Open, WPA2 PSK, WPA2 PSK/WPA3 SAE, WPA3 SAE.

## What It Does
- Prompts for SSID, encryption type, and password
- Saves profiles persistently across firmware upgrades
- Allows delete-all, delete-one, add-new, and view operations

## Uninstall
- Delete `/root/payloads/switch_client_wifi_configuration/`.
- Optional: remove saved profiles with the configuration payload.

## Troubleshooting
- If the picker shows no networks, add profiles here first.

## Changelog
- 1.0: Initial configuration payload
