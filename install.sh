#!/usr/bin/env bash
# install.sh - install battery-alert for the current user and start it.
#
#   ./install.sh              install into ~/.local and ~/.config/systemd/user
#   ./install.sh --uninstall  stop it and remove the installed files
#
# The systemd unit runs %h/.local/bin/battery-alert, so the target directory
# is fixed; moving the binary elsewhere means editing the unit as well.

set -euo pipefail

cd "$(dirname "$0")"

BIN_DIR="$HOME/.local/bin"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

if [[ ${1:-} == "--uninstall" ]]; then
    systemctl --user disable --now battery-alert.service 2>/dev/null || true
    rm -f "$UNIT_DIR/battery-alert.service" "$BIN_DIR/battery-alert"
    systemctl --user daemon-reload
    echo "battery-alert removed"
    exit 0
fi

install -Dm755 bin/battery-alert "$BIN_DIR/battery-alert"
install -Dm644 systemd/battery-alert.service "$UNIT_DIR/battery-alert.service"

systemctl --user daemon-reload
systemctl --user enable --now battery-alert.service

echo "battery-alert installed:"
echo "  $BIN_DIR/battery-alert"
echo "  $UNIT_DIR/battery-alert.service"
echo
echo "Check it with:  battery-alert --status"
