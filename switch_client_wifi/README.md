**Client Wifi Picker**

**Overview**
This payload switches the WiFi Pineapple Pager into client mode WiFi by selecting
from saved SSID profiles. It prompts the user, applies the chosen network settings
via UCI, and reloads wireless.

**What it does**
- Presents a menu of configured SSIDs via Pager dialogs
- Prompts for a selection and confirmation
- Updates the client mode (sta) wireless profile with the selected SSID,
  encryption type, and password
- Reloads WiFi to apply changes (with a 20-second timeout)
- Writes status updates to the Pager log throughout the process

**Configuration**
The payload stores profiles using the Pager CONFIG commands:
`PAYLOAD_SET_CONFIG`, `PAYLOAD_GET_CONFIG`, and `PAYLOAD_DEL_CONFIG`. These values
persist across firmware upgrades.

On first run, the payload prompts you to enter SSIDs, encryption types, and passwords,
then saves them as persistent options under the payload name `switch_client_wifi`.
If profiles already exist, you will be prompted to reconfigure or keep them.

**Notes**
- Encryption choices: Open, WPA2 PSK, WPA2 PSK/WPA3 SAE, WPA3 SAE (personal).
- The script detects the first `sta` section in `uci show wireless`. If none is
  found, it defaults to `wlan0cli`.

**Usage**
1) Copy the payload folder to the Pager.
2) Run the payload and enter SSIDs, encryption types, and passwords when prompted.
3) Select the desired network from the prompt.

**Files**
- `payload.sh`: Main payload script for the Pager
