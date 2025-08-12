# Script to remove the Proxmox Backup Server no subscription nag.
################################################
# !!!PLEASE USE THIS SCRIPT ONLY FOR HOMELAB!!!#
################################################
# Copyright (c) 2025 Bloodpack
# Author: Bloodpack 
# License: GPL-3.0 license
# Follow or contribute on GitHub here:
# https://github.com/Bloodpack/proxmox_nag_removal.git
#################################
# VERSION: 2.00 from 08.08.2025 #
#################################



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
