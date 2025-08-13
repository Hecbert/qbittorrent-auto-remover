<img width="1920" height="500" alt="escape" src="https://github.com/user-attachments/assets/5e02a984-1b85-4249-b0fd-56dba9dd7fbf" />

Automatically deletes torrents in **qBittorrent** if they are larger than the free space (minus a safety margin) on the drive, and sends a notification to a **Discord** channel via webhook.

## How It Works
- Checks free space and subtracts a safety margin (**MARGIN_GB**).
- If torrent size is larger than that limit:
  - Sends a notification to Discord (embed + fallback text).
  - Deletes the torrent using qBittorrent Web API.
- If it fits, does nothing.

## Setup
1. Edit the script and set:
   - **QB_USER** → your qBittorrent username  
   - **QB_PASS** → your qBittorrent password  
   - **DISCORD_WEBHOOK** → your Discord webhook URL
2. Make the script executable:
   ```bash
   chmod +x /path/to/qb_guard.sh

3. In qBittorrent, go to Preferences → Downloads → Run external program on torrent added and set:
   ```bash
   /path/to/qb_guard.sh "%N" "%Z" "%D" "%I"

## Variables
- **MARGIN_GB** → GB to keep free (default: 10)
- **QB_URL** → qBittorrent Web UI URL (default: http://localhost:9500)
- **LOG_FILE** → Log file location (default: /media/scripts/qb_guard.log)
- **DRY_RUN** → Set to 1 to test without deleting torrents
