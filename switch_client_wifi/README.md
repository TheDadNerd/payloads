# Client WiFi Picker

Switches client mode WiFi between saved networks on the WiFi Pineapple Pager.

## Overview
This payload presents a menu of saved SSIDs, applies the selected network
configuration via UCI, and reloads wireless.

## Requirements
- Hak5 WiFi Pineapple Pager
- Saved WiFi profiles (configure first)

## Installation
1) Copy `switch_client_wifi` and `switch_client_wifi_configuration` to `/root/payloads/`.

## Usage
1) Run `switch_client_wifi_configuration` to save SSIDs and passwords.
2) Run `switch_client_wifi` and select a network.

## Configuration
- Profiles are stored using `PAYLOAD_SET_CONFIG` under `switch_client_wifi`.
- The client interface section used is `wlan0cli`.

## What It Does
- Displays a list of configured SSIDs
- Prompts for selection and confirmation
- Updates SSID, encryption, and key in UCI
- Reloads WiFi to apply changes

## Uninstall
- Delete `/root/payloads/switch_client_wifi/` and `/root/payloads/switch_client_wifi_configuration/`.
- Optional: remove saved profiles with the configuration payload.

## Troubleshooting
- If no profiles appear, run the configuration payload first.
- If passwords mismatch, re-enter profiles in the configuration payload.

## Changelog
- 1.0: Initial client WiFi picker
