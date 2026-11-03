#!/usr/bin/env bash
set -euo pipefail

repo="dylanjphelps/steamos-wifi-bgscan"
dispatcher_url="https://raw.githubusercontent.com/${repo}/main/src/dispatcher"
dispatcher_path="/etc/NetworkManager/dispatcher.d/90-steamos-wifi-bgscan"
script_dir=""
if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for command in nmcli sudo; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command" >&2
        exit 1
    fi
done

dispatcher_source="${script_dir:+${script_dir}/src/dispatcher}"
if [[ -z "$script_dir" || ! -f "$dispatcher_source" ]]; then
    if ! command -v curl >/dev/null 2>&1; then
        printf 'Required command not found: curl\n' >&2
        exit 1
    fi
    dispatcher_source="${tmp_dir}/dispatcher"
    curl --fail --location --silent --show-error \
        "$dispatcher_url" --output "$dispatcher_source"
fi

printf 'Installing the SteamOS Wi-Fi background-scan dispatcher...\n'
sudo install -D -m 0755 "$dispatcher_source" "$dispatcher_path"

connected_wifi_devices="$(
    nmcli -t --escape no -f DEVICE,TYPE,STATE device status |
        awk -F: '$2 == "wifi" && $3 == "connected" { print $1 }'
)"
if [[ -n "$connected_wifi_devices" ]]; then
    while IFS= read -r device; do
        [[ "$device" =~ ^[[:alnum:]_.-]+$ ]] || continue
        sudo "$dispatcher_path" "$device" up
    done <<< "$connected_wifi_devices"
else
    printf 'No connected Wi-Fi device found; the fix will apply on the next connection.\n'
fi

printf 'Installed. The setting is applied when wpa_supplicant reports a connected Wi-Fi network.\n'
