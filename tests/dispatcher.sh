#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "${tmp_dir}/bin"

cat >"${tmp_dir}/bin/nmcli" <<'EOF'
#!/bin/sh
case "$*" in
    *"device status"*) printf 'wlp2s0:wifi:connected\n' ;;
    *eth0*) printf 'ethernet\n' ;;
    *) printf 'wifi\n' ;;
esac
EOF

cat >"${tmp_dir}/bin/wpa_cli" <<'EOF'
#!/bin/sh
case "$3" in
    list_networks)
        if [ "${MOCK_LIST_FAIL:-0}" = 1 ]; then
            exit 1
        fi
        if [ "${MOCK_NO_CURRENT:-0}" = 1 ]; then
            printf 'network id / ssid / bssid / flags\n17 Example any\n'
            exit 0
        fi
        printf 'network id / ssid / bssid / flags\n17 Example any [CURRENT]\n'
        ;;
    set_network)
        printf '%s\n' "$*" >>"$WPA_CALL_LOG"
        if [ "${MOCK_SET_FAIL:-0}" = 1 ]; then
            printf 'FAIL\n'
        else
            printf 'OK\n'
        fi
        ;;
esac
EOF

cat >"${tmp_dir}/bin/logger" <<'EOF'
#!/bin/sh
exit 0
EOF

cat >"${tmp_dir}/bin/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$SUDO_CALL_LOG"
exec "$@"
EOF

chmod +x "${tmp_dir}/bin/"*
export PATH="${tmp_dir}/bin:${PATH}"
export WPA_CALL_LOG="${tmp_dir}/wpa-calls"
export SUDO_CALL_LOG="${tmp_dir}/sudo-calls"

"${repo_dir}/src/dispatcher" wlp2s0 up
grep -F -- '-i wlp2s0 set_network 17 bgscan ""' "$WPA_CALL_LOG" >/dev/null
call_count="$(wc -l <"$WPA_CALL_LOG")"

"${repo_dir}/src/dispatcher" wlp2s0 down
"${repo_dir}/src/dispatcher" eth0 up
[[ "$(wc -l <"$WPA_CALL_LOG")" -eq "$call_count" ]]

if MOCK_LIST_FAIL=1 "${repo_dir}/src/dispatcher" wlp2s0 up; then
    printf 'Expected dispatcher to fail when wpa_supplicant is unavailable.\n' >&2
    exit 1
fi

if MOCK_NO_CURRENT=1 "${repo_dir}/src/dispatcher" wlp2s0 up; then
    printf 'Expected dispatcher to fail when no network is active.\n' >&2
    exit 1
fi

if MOCK_SET_FAIL=1 "${repo_dir}/src/dispatcher" wlp2s0 up; then
    printf 'Expected dispatcher to fail when wpa_supplicant rejects the setting.\n' >&2
    exit 1
fi

if MOCK_NO_CURRENT=1 "${repo_dir}/install.sh" >"${tmp_dir}/install-output" 2>&1; then
    printf 'Expected installer to reject a connected interface without a current wpa_supplicant network.\n' >&2
    exit 1
fi
grep -F 'This fix requires the wpa_supplicant backend; no files were installed.' \
    "${tmp_dir}/install-output" >/dev/null
if grep -F 'install ' "$SUDO_CALL_LOG" >/dev/null; then
    printf 'Installer wrote files before backend validation.\n' >&2
    exit 1
fi

printf 'Dispatcher tests passed.\n'
