#!/bin/sh
# Removes the test driver: fprintd goes back to the system libfprint.
# Run as your normal user: ./uninstall.sh
set -eu

DEST=/opt/libfprint-00a2
DROPIN_DIR=/etc/systemd/system/fprintd.service.d

# Prints enrolled with the test driver are useless without it.
if command -v fprintd-delete >/dev/null; then
    fprintd-delete "$(id -un)" 2>/dev/null || true
fi

sudo rm -f "$DROPIN_DIR/libfprint-00a2.conf" "$DROPIN_DIR/libfprint-00a2-debug.conf"
sudo rmdir "$DROPIN_DIR" 2>/dev/null || true
sudo rm -rf "$DEST"
sudo systemctl daemon-reload
sudo systemctl stop fprintd.service 2>/dev/null || true

echo "Test driver removed. The work/ folder can be deleted."
