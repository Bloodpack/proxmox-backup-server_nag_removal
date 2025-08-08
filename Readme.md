# Proxmox Backup Server Subscription Nag Disable Script

# This only works for Proxmox Backup Server Version 4 and above

This repository contains a script and an APT hook to automatically disable the "No valid subscription" nag in Proxmox Backup Server version 4 by patching the `proxmoxlib.js` file.

---

## How it Works

- ✅ Creates a timestamped backup of the original `proxmoxlib.js` file (keeps last 3 backups only).
- ✅ Patches the JavaScript to bypass the subscription nag check.
- ✅ Restarts the `proxmox-backup-proxy` service to apply changes.
- ✅ Automatically runs after package installations/updates via an APT hook.

---

📁 File Structure

```shell
/usr/local/sbin/remove-pbs-nag.sh               # Patch script
/etc/apt/apt.conf.d/99-pve-no-nag               # APT hook
/usr/share/javascript/proxmox-widget-toolkit/   # Target JS file + backups
```
🛠️ Installation Instructions

You must be logged in as root (no sudo required).

1. Create the patch script
```
nano /usr/local/sbin/remove-pbs-nag.sh
```

```bash
#!/bin/bash

JS_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
BACKUP_DIR="/usr/share/javascript/proxmox-widget-toolkit"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/proxmoxlib.js.bak.${TIMESTAMP}"

# Check if file exists
if [ ! -f "$JS_FILE" ]; then
    echo "[no-nag] ERROR: $JS_FILE not found."
    exit 1
fi

# Check if already patched
if grep -q "NoMoreNagging" "$JS_FILE"; then
    echo "[no-nag] Already patched."
    exit 0
fi

# Backup original
cp "$JS_FILE" "$BACKUP_FILE"
echo "[no-nag] Backup created: $BACKUP_FILE"

# Rotate backups, keep only last 3
BACKUPS=($(ls -1t ${BACKUP_DIR}/proxmoxlib.js.bak.* 2>/dev/null))
NUM_BACKUPS=${#BACKUPS[@]}
if [ "$NUM_BACKUPS" -gt 3 ]; then
    for ((i=3; i<NUM_BACKUPS; i++)); do
        rm -f "${BACKUPS[$i]}"
        echo "[no-nag] Removed old backup: ${BACKUPS[$i]}"
    done
fi

# Apply patch for PBS v4
sed -i "s/\.toLowerCase() !== 'active'/=== 'NoMoreNagging'/g" "$JS_FILE"

# Confirm patch
if grep -q "NoMoreNagging" "$JS_FILE"; then
    echo "[no-nag] Patch applied successfully."

    # Restart proxmox-backup-proxy to reload patched JS
    if systemctl restart proxmox-backup-proxy; then
        echo "[no-nag] Restarted proxmox-backup-proxy successfully."
    else
        echo "[no-nag] Failed to restart proxmox-backup-proxy!"
        exit 1
    fi

else
    echo "[no-nag] Patch failed, restoring backup..."
    cp "$BACKUP_FILE" "$JS_FILE"
    exit 1
fi
```


2. Make the script executable:

```bash
chmod +x /usr/local/sbin/remove-pbs-nag.sh
```
3. APT Hook:

```bash
nano /etc/apt/apt.conf.d/99-pbs-no-nag
```

paste content below to run the script automatically after package operations:

```bash
DPkg::Post-Invoke {
  "if [ -x /usr/local/sbin/remove-pbs-nag.sh ]; then /usr/local/sbin/remove-pbs-nag.sh; fi";
};
```

4. to run this manually just run this command in your shell

```bash
/usr/local/sbin/remove-pbs-nag.sh
```
5. Check that backups exist:

```shell
ls -lt /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak.*
```
🧠 Notes

This script does not affect any Proxmox functionality — it only bypasses the UI nag.

Backups are stored in the same directory as the original JS file.

Be sure to clear your browser cache after patching.

🛑 Disclaimer

Use at your own risk. This script modifies Proxmox UI files, which could be overwritten during updates. The APT hook helps to reapply the patch automatically, but always check after major upgrades.

This is intended for homelab or non-production environments where the subscription nag is undesired.

