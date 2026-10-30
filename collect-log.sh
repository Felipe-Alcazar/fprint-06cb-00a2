#!/bin/sh
# Collects a debug log for a test report. Turns on fprintd's debug output,
# lets you reproduce the problem, then writes report-<date>.txt and turns
# debug off again. Run as your normal user: ./collect-log.sh
set -eu

DEBUG_DROPIN=/etc/systemd/system/fprintd.service.d/libfprint-00a2-debug.conf
out="report-$(date +%Y%m%d-%H%M%S).txt"

sudo tee "$DEBUG_DROPIN" >/dev/null <<CONF
[Service]
Environment=G_MESSAGES_DEBUG=all
CONF
sudo systemctl daemon-reload
sudo systemctl stop fprintd.service 2>/dev/null || true
since=$(date '+%Y-%m-%d %H:%M:%S')

echo "Debug log is on. Now repeat what went wrong"
echo "(for example fprintd-enroll or fprintd-verify in another terminal)."
printf "When you are done, press Enter here... "
read -r _

{
    echo "== system"; uname -r; grep PRETTY_NAME /etc/os-release || true
    echo "== machine"; cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_version 2>/dev/null || true
    echo "== usb"; lsusb 2>/dev/null | grep -i 06cb || true
    echo "== fprintd"; fprintd --version 2>/dev/null || true
    echo "== driver"; cat /etc/systemd/system/fprintd.service.d/libfprint-00a2.conf 2>/dev/null || echo "test driver not installed"
    echo "== log"; sudo journalctl -u fprintd.service --since "$since" --no-pager
} >"$out" 2>&1

sudo rm -f "$DEBUG_DROPIN"
sudo systemctl daemon-reload
sudo systemctl stop fprintd.service 2>/dev/null || true

echo "Log saved to $out. Read it before sending, then attach it to your report."
