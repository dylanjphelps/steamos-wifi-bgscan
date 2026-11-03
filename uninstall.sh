#!/usr/bin/env bash
set -euo pipefail

dispatcher_path="/etc/NetworkManager/dispatcher.d/90-steamos-wifi-bgscan"
update_keep_list="/etc/atomic-update.conf.d/steamos-wifi-bgscan.conf"

if ! command -v sudo >/dev/null 2>&1; then
    printf 'Required command not found: sudo\n' >&2
    exit 1
fi

sudo rm -f "$dispatcher_path" "$update_keep_list"
printf 'Uninstalled. Reconnect Wi-Fi to restore default scan behavior for the current connection.\n'
