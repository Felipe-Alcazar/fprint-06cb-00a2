# Synaptics 06cb:00a2 fingerprint reader on Linux (testing)

**Test** driver for the Synaptics `06cb:00a2` fingerprint reader found in
ThinkPads such as the **L380 Yoga** (where it was developed and tested).
This reader does not work on Linux today. This kit builds a version of
[libfprint](https://gitlab.freedesktop.org/libfprint/libfprint) that supports
it, so more people can test it before the code is sent upstream.

It works with your distribution's stock fprintd: enrollment from GNOME/KDE
settings, lock screen, login and `sudo`.

## Before you start

- Check that you have this reader: `lsusb | grep 06cb:00a2`
- **The reader must have been used by Windows at least once** (most laptops
  ship that way). The driver reuses the pairing Windows set up and **never
  writes to the sensor's memory**. Readers that never ran under Windows have
  not been tested.
- If you installed `python-validity` / `open-fprintd`, remove them first.
- Tested on Ubuntu 26.10 (fprintd 1.94). The script also lists the packages
  for Fedora and Arch, but those are untested.

## Install

```sh
git clone https://github.com/Felipe-Alcazar/fprint-06cb-00a2.git
cd fprint-06cb-00a2
./install.sh
```

It asks for your `sudo` password. The script:

1. installs the build tools (and `fprintd`);
2. downloads and builds libfprint with the driver;
3. downloads Lenovo's official Windows driver (`r0rgn10w.exe`) and extracts
   the sensor's init block from it. The file is checked by its hash and only
   unpacked; nothing in it is run. This block cannot be redistributed, so
   everyone extracts their own;
4. installs everything to `/opt/libfprint-00a2` and makes only `fprintd`
   load it. The system libfprint is not touched.

Then enroll a finger with `fprintd-enroll` (or in Settings > Users) and test
it with `fprintd-verify`. To use it for login and `sudo` on Ubuntu/Debian:
`sudo pam-auth-update --enable fprintd`.

## How to help

[Open an issue](https://github.com/Felipe-Alcazar/fprint-06cb-00a2/issues)
with:

- your laptop model and distribution;
- whether install, enroll and verify worked, and how many misses in ~10 tries;
- if something failed, the log from `./collect-log.sh` (read it before
  sending).

"It works" reports help a lot too.

## Remove

```sh
./uninstall.sh
```

This deletes the prints enrolled with the test driver, removes the files from
`/opt` and puts fprintd back to normal.

## How it works

The 06cb:00a2 is a "match-on-host" reader: it only takes a picture of the
finger, and the computer does the matching. The driver builds on libfprint's
`validity` driver, still under review in
[MR !626](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/626),
which already supports other readers of the same family. The 00a2 part (image
download, enrollment and SIFT + RANSAC matching) lives in the
[`fp-00a2-dev`](https://github.com/Felipe-Alcazar/libfprint/tree/fp-00a2-dev)
branch.

After testing, the plan is to send this support to libfprint upstream so it
reaches distributions without this kit.

The scripts in this kit are MIT licensed. libfprint is LGPL-2.1.
