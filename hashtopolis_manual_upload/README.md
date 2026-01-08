# Hashtopolis Handshake Upload

Manually upload captured WPA handshakes from a WiFi Pineapple Pager to a
Hashtopolis server via API.

## Overview
This payload validates connectivity and API credentials, uploads `.22000`
handshakes from `/root/loot/handshakes`, creates hashlists, and starts the
preconfigured task for cracking. It can optionally delete handshakes after a
successful upload.

## Requirements
- Hak5 WiFi Pineapple Pager with internet connectivity
- Hashtopolis server (v0.5.0+)
- Hashtopolis API access and a preconfigured task
- Hashcat cracker version ID

## Installation
1) Copy `hashtopolis_manual_upload` to `/root/payloads/user/general/`.
2) Create `hashtopolis_manual_upload/config.sh` with your server details.

## Usage
1) Run the payload from the Pager UI.
2) When prompted, choose whether to save `config.sh` values into persistent payload config.
3) Follow prompts to upload and optionally clean up handshakes.

You can also provide a custom handshake directory as the first argument:

```bash
./payload.sh /path/to/handshakes
```

## Configuration
Create `config.sh` in the same directory as `payload.sh`:

```bash
HASHTOPOLIS_URL="https://your-server/api/server.php"
API_KEY="YOUR_API_KEY_HERE"
PRETASK_ID="7"
CRACKER_VERSION_ID="1"
HASH_TYPE="22000"
ACCESS_GROUP_ID="1"
SECRET_HASHLIST=false
USE_BRAIN=false
BRAIN_FEATURES=0
```

The payload stores these values in `PAYLOAD_SET_CONFIG` when you confirm the
prompt. On later runs it loads from the saved config instead of reading the
file directly.

If `config.sh` still has the sample `example.com` URL or `YOUR_API_KEY_HERE`,
the payload warns you and offers to exit so you can update the file before
saving.

To force an update without the prompt, run:

```bash
./payload.sh --update-config
```

### Hashtopolis Setup (Summary)
1) Create an API key: Users > API Management.
2) Upload wordlists/rules: Files > New File.
3) Create a preconfigured task: Tasks > New Preconfigured Task.
4) Note the pretask ID from the URL.
5) Find the Hashcat version ID: Config > Crackers.

## What It Does
- Validates Hashtopolis API connectivity
- Uploads `.22000` handshakes as hashlists
- Launches a preconfigured task for each upload
- Reports success/errors and prompts for cleanup

## Uninstall
- Delete `/root/payloads/hashtopolis_manual_upload/`.
- Remove any saved API keys in Hashtopolis if desired.

## Troubleshooting
- If API tests fail, verify `HASHTOPOLIS_URL` and network access.
- If authentication fails, regenerate the API key and update `config.sh`.
- If uploads fail, confirm `.22000` files exist in `/root/loot/handshakes`.

## Changelog
- 1.0: Initial manual upload payload
- 2.0: Save config to `PAYLOAD_SET_CONFIG` to preserve settings across mass payload updates.
