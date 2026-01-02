**Overview**
This payload switches the WiFi Pineapple Pager into client mode WiFi by selecting
from a hardcoded list of SSID/password profiles. It prompts the user, applies the chosen
network settings via UCI, reloads wireless, and waits for a client IP to confirm connectivity.

**What it does**
- Presents a menu of configured SSIDs via Pager dialogs
- Prompts for a selection and confirmation
- Updates the client mode (sta) wireless profile with the selected SSID,
  encryption type, and password
- Reloads WiFi to apply changes
- Waits for an IP on the client interface and reports success or failure
- Writes status updates to the Pager log throughout the process

**Configuration**
The payload reads its profiles from `/root/payloadconfigs/switch_client_wifi/networks.conf`.
If the file does not exist, it will be created automatically on first run. You will
be prompted to enter SSIDs and passwords on the Pager. You can also create or edit
the config file ahead of time in that directory.

The config file includes these arrays:
- `SSIDS`: List of WiFi network names
- `PASSWORDS`: Matching passwords (same order as SSIDS)
- `ENCRYPTIONS`: Optional list of per-network encryption types

**Notes**
- Set encryption to `none` for open networks. If a password is blank, the payload
  will also switch to `none`.
- The script detects the first `sta` section in `uci show wireless`. If none is
  found, it defaults to `wlan0cli`.

**Usage**
1) Copy the payload folder to the Pager.
2) Run the payload to create `/root/payloadconfigs/switch_client_wifi/networks.conf`.
3) Enter SSIDs and passwords when prompted, or edit the config file manually.
4) Re-run the payload and select the desired network from the prompt.

**Files**
- `payload.sh`: Main payload script for the Pager
