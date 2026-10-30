#!/bin/sh
# Installs the test driver for the Synaptics 06cb:00a2 fingerprint reader.
# Builds libfprint (validity driver + 06cb:00a2) and puts it in
# /opt/libfprint-00a2, loaded only by fprintd. The system libfprint is not
# touched. Undo: ./uninstall.sh
#
# Run as your normal user (not root): ./install.sh
set -eu

LIBFPRINT_REPO=https://github.com/Felipe-Alcazar/libfprint.git
LIBFPRINT_COMMIT=4b5b6d83570eb56be710a539b6e1dd5b5d78026f
DATA_REPO=https://gitlab.freedesktop.org/ggiesen/libfprint-validity-data.git
DATA_COMMIT=687c5ea51392582d5bcb1e4fa86eea0832a50c5f
DEST=/opt/libfprint-00a2
DROPIN=/etc/systemd/system/fprintd.service.d/libfprint-00a2.conf

here=$(cd "$(dirname "$0")" && pwd)
work="$here/work"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run as your normal user (without sudo); the script asks for the password when needed"

say "Looking for the 06cb:00a2 reader"
found=no
for d in /sys/bus/usb/devices/*; do
    [ -f "$d/idVendor" ] || continue
    if [ "$(cat "$d/idVendor")" = 06cb ] && [ "$(cat "$d/idProduct")" = 00a2 ]; then
        found=yes
    fi
done
[ "$found" = yes ] || die "06cb:00a2 reader not found (check with: lsusb | grep 06cb)"

# python-validity / open-fprintd take the same D-Bus name and the same sensor.
for svc in open-fprintd python3-validity; do
    if systemctl is-active --quiet "$svc.service" 2>/dev/null; then
        die "the $svc service is running; remove python-validity/open-fprintd first"
    fi
done

say "Installing dependencies"
if command -v apt-get >/dev/null; then
    sudo apt-get install -y git meson ninja-build gcc pkg-config libglib2.0-dev \
        libgusb-dev libpixman-1-dev libssl-dev libgudev-1.0-dev libudev-dev \
        innoextract python3 fprintd libpam-fprintd
elif command -v dnf >/dev/null; then
    sudo dnf install -y git meson ninja-build gcc pkgconf-pkg-config glib2-devel \
        libgusb-devel pixman-devel openssl-devel libgudev-devel systemd-devel \
        innoextract python3 fprintd fprintd-pam
elif command -v pacman >/dev/null; then
    sudo pacman -S --needed --noconfirm git meson ninja gcc pkgconf glib2 libgusb \
        pixman openssl libgudev innoextract python fprintd
else
    die "unknown distribution; install the dependencies listed in the README and run again"
fi

fetch() { # repo commit dir
    if [ ! -d "$3/.git" ]; then
        git clone --quiet "$1" "$3"
    fi
    git -C "$3" fetch --quiet origin
    git -C "$3" checkout --quiet --detach "$2"
}

mkdir -p "$work"

say "Downloading and building libfprint"
fetch "$LIBFPRINT_REPO" "$LIBFPRINT_COMMIT" "$work/libfprint"
if [ ! -d "$work/libfprint/build" ]; then
    meson setup "$work/libfprint/build" "$work/libfprint" -Ddrivers=validity \
        -Dintrospection=false -Ddoc=false -Dgtk-examples=false \
        -Dinstalled-tests=false -Dudev_rules=disabled -Dudev_hwdb=disabled
fi
ninja -C "$work/libfprint/build"

say "Generating the sensor data"
fetch "$DATA_REPO" "$DATA_COMMIT" "$work/validity-data"
make -C "$work/validity-data" generate >/dev/null
python3 -I "$here/extract_init.py" "$work/validity-data/output"

say "Installing to $DEST"
lib="$work/libfprint/build/libfprint"
sudo rm -rf "$DEST.new"
sudo mkdir -p "$DEST.new/lib" "$DEST.new/validity-data"
sudo cp -P "$lib/libfprint-2.so" "$lib/libfprint-2.so.2" "$lib/libfprint-2.so.2.0.0" "$DEST.new/lib/"
sudo cp -r "$work/validity-data/output/." "$DEST.new/validity-data/"
sudo chown -R root:root "$DEST.new"
sudo chmod -R go-w "$DEST.new"
sudo rm -rf "$DEST"
sudo mv "$DEST.new" "$DEST"

# fprintd runs with ProtectHome, so everything it loads lives under /opt.
sudo mkdir -p "$(dirname "$DROPIN")"
sudo tee "$DROPIN" >/dev/null <<CONF
[Service]
Environment=LD_LIBRARY_PATH=$DEST/lib
Environment=VALIDITY_DATA_DIR=$DEST/validity-data
CONF
sudo systemctl daemon-reload
sudo systemctl stop fprintd.service 2>/dev/null || true

say "Done"
cat <<'MSG'
Enroll a finger:   fprintd-enroll
Test it:           fprintd-verify
Or use Settings > Users > Fingerprint Login.
For login/sudo (Ubuntu/Debian): sudo pam-auth-update --enable fprintd
If something fails: ./collect-log.sh   To remove: ./uninstall.sh
MSG
