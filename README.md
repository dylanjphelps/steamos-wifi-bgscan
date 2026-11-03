# SteamOS Wi-Fi Background Scan Fix

Disable wpa_supplicant's periodic background scans for the active Wi-Fi
network. The NetworkManager dispatcher runs on every Wi-Fi connection, so the
fix applies to the Steam Deck, Steam Frame, Steam Machine, and other SteamOS
hardware without assuming a particular Wi-Fi interface name.

## Install

In SteamOS desktop mode, open Konsole and run:

```sh
curl -fsSL https://raw.githubusercontent.com/dylanjphelps/steamos-wifi-bgscan/main/install.sh | bash
```

The installer asks for administrator permission and applies the setting to
currently connected Wi-Fi interfaces. It also installs a dispatcher so the
setting is applied after future connections.

SteamOS keeps `/etc` on a writable overlay even while the base system
filesystem is read-only, so this installer should not require disabling
read-only mode. SteamOS updates may discard `/etc` files that are not on the
update keep-list. This installer does not add the dispatcher to that list, so
check whether it is still installed after a system update and reinstall if
needed.

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/dylanjphelps/steamos-wifi-bgscan/main/uninstall.sh | bash
```

The uninstaller removes only this tool's NetworkManager dispatcher. If the
current connection has already had background scanning disabled, disconnect
and reconnect Wi-Fi to let wpa_supplicant reload the network settings.

## Compatibility and trade-offs

This works with the NetworkManager **wpa_supplicant** backend, independent of
the Wi-Fi device name. It does not support NetworkManager's **iwd** backend:
iwd has no equivalent supported per-network setting to disable its background
scans. If your SteamOS installation uses iwd, switch to wpa_supplicant before
installing this fix.

With background scans disabled, the device will not actively look for a better
access point while connected. Roaming between access points may therefore be
slower or may not happen until the current connection drops. Access-point
assisted roaming may still work. This changes neither scans made while
disconnected nor scans explicitly requested by the system or user.
