# WiFi Pineapple Pager Payloads

Repository of custom payloads for the Hak5 WiFi Pineapple Pager.

## Overview
This repo contains payloads for common workflows like client WiFi switching,
wardriving activation, and manual Hashtopolis uploads.

## Requirements
- Hak5 WiFi Pineapple Pager
- USB GPS receiver (for wardrive payloads)
- Internet access (for Hashtopolis uploads)

## Installation
1) Clone this repo.
2) Copy the desired payload folder to your Pager under `/root/payloads/`.

## Usage
1) Run the payload from the Pager UI.
2) Follow on-screen prompts or alerts.

## Configuration
- Some payloads store settings using `PAYLOAD_SET_CONFIG` for persistence.
- See each payload README for specific configuration steps.

## What It Does
- Provides reusable payloads for the Pager
- Documents setup and usage for each payload
- Supports both manual and automated workflows

## Uninstall
- Remove the payload folder from `/root/payloads/`.

## Troubleshooting
- Ensure the payload folder name matches the expected path in the README.
- Verify required hardware (GPS, network) is connected and ready.

## Changelog
- 1.0: Initial repository layout
