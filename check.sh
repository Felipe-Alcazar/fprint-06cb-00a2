#!/bin/sh
# Checks whether this computer can run the test driver. Changes nothing and
# needs no password. Run: sh check.sh
ok=yes

model=$(cat /sys/class/dmi/id/product_version 2>/dev/null)
printf 'Computer:  %s %s\n' "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)" "$model"
printf 'System:    %s\n' "$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"

reader=no
for d in /sys/bus/usb/devices/*; do
    [ -f "$d/idVendor" ] || continue
    if [ "$(cat "$d/idVendor")" = 06cb ] && [ "$(cat "$d/idProduct")" = 00a2 ]; then
        reader=yes
    fi
done
if [ "$reader" = yes ]; then
    echo "Reader:    06cb:00a2 found"
else
    echo "Reader:    06cb:00a2 NOT found. This kit is only for that reader."
    ids=$(for d in /sys/bus/usb/devices/*; do
        [ "$(cat "$d/idVendor" 2>/dev/null)" = 06cb ] && echo "06cb:$(cat "$d/idProduct")"
    done)
    [ -n "$ids" ] && echo "           Synaptics devices here: $ids"
    ok=no
fi

if command -v systemctl >/dev/null; then
    echo "systemd:   yes"
else
    echo "systemd:   NO (the installer configures fprintd through systemd)"
    ok=no
fi

for svc in open-fprintd python3-validity; do
    if systemctl is-active --quiet "$svc.service" 2>/dev/null; then
        echo "Conflict:  $svc is running; remove python-validity/open-fprintd first"
        ok=no
    fi
done

if [ -f /etc/systemd/system/fprintd.service.d/libfprint-00a2.conf ]; then
    echo "Test driver: already installed"
fi

if command -v apt-get >/dev/null || command -v dnf >/dev/null || command -v pacman >/dev/null; then
    :
else
    echo "Packages:  unknown package manager; install the dependencies by hand (see README)"
fi

echo
if [ "$ok" = yes ]; then
    echo "Looks good. Next step: ./install.sh"
else
    echo "This computer is not ready for the test driver (see above)."
    exit 1
fi
