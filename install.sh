#!/usr/bin/env bash
set -euo pipefail

repo="dylanjphelps/steamos-wifi-bgscan"
dispatcher_url="https://raw.githubusercontent.com/${repo}/main/src/dispatcher"
dispatcher_path="/etc/NetworkManager/dispatcher.d/90-steamos-wifi-bgscan"
update_keep_list="/etc/atomic-update.conf.d/steamos-wifi-bgscan.conf"
script_dir=""
if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for command in nmcli sudo wpa_cli; do
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

connected_wifi_devices="$(
    nmcli -t --escape no -f DEVICE,TYPE,STATE device status |
        awk -F: '$2 == "wifi" && $3 == "connected" { print $1 }'
)"
if [[ -n "$connected_wifi_devices" ]]; then
    while IFS= read -r device; do
        [[ "$device" =~ ^[[:alnum:]_.-]+$ ]] || continue
        if ! sudo wpa_cli -i "$device" list_networks >"${tmp_dir}/networks" 2>/dev/null ||
            ! awk '$NF == "[CURRENT]" { found = 1 } END { exit !found }' "${tmp_dir}/networks"; then
            printf 'Cannot find the active wpa_supplicant network on %s. This fix requires the wpa_supplicant backend; no files were installed.\n' \
                "$device" >&2
            exit 1
        fi
    done <<< "$connected_wifi_devices"
else
    printf 'No connected Wi-Fi device found; the backend cannot be verified until a network connects.\n'
fi

sudo install -D -m 0755 "$dispatcher_source" "$dispatcher_path"

if [[ -d /etc/atomic-update.conf.d ]]; then
    printf '%s\n' "$dispatcher_path" >"${tmp_dir}/update-keep-list"
    sudo install -m 0644 "${tmp_dir}/update-keep-list" "$update_keep_list"
    printf 'Registered the dispatcher to survive SteamOS updates.\n'
else
    printf 'SteamOS update keep-list directory not found; reinstall after a system update if needed.\n' >&2
fi

if [[ -n "$connected_wifi_devices" ]]; then
    apply_failures=0
    while IFS= read -r device; do
        [[ "$device" =~ ^[[:alnum:]_.-]+$ ]] || continue
        if ! sudo "$dispatcher_path" "$device" up; then
            printf 'Installed, but could not apply the setting immediately on %s; check the system journal.\n' \
                "$device" >&2
            apply_failures=$((apply_failures + 1))
        fi
    done <<< "$connected_wifi_devices"
    if (( apply_failures == 0 )); then
        printf 'Installed and applied to the connected wpa_supplicant network(s).\n'
    else
        printf 'Installation is in place, but the setting was not applied to every connected interface.\n' >&2
        exit 1
    fi
else
    printf 'Installed. The setting will apply when a wpa_supplicant Wi-Fi network connects.\n'
fi
