**Wardriving On**

**Overview**
This payload detects GPS devices on the WiFi Pineapple Pager, sets the active
device in `gpsd` configuration, and restarts the GPS daemon to ensure it is using
the correct hardware.

**What it does**
- Scans common Pager USB GPS device paths under `/dev` (ACM/USB)
- Uses the configured `gpsd.core.device` if it is present
- Prompts to pick a device when multiple candidates are found
- Enables gpsd, writes the selected device to UCI, and restarts gpsd
- Starts Wigle logging when GPS is configured
- Shows Pager status updates throughout the process

**Usage**
1) Copy the `wardriving_on` payload folder to the Pager.
2) Run the payload.
3) Select a GPS device if prompted.

**Notes**
- If no GPS devices are detected, the payload exits with an error.
- The selected device is saved in `gpsd.core.device` for future runs.

**Files**
- `payload.sh`: Main payload script
