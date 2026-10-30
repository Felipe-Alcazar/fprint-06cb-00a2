# Linux driver for the Synaptics 06cb:00a2 fingerprint reader (testing)

**Make the fingerprint reader of your ThinkPad L380, L380 Yoga, L390 Yoga,
S2 Yoga, E480, E490, E580 or E590 work on Linux.**

This is a **test** driver for the Synaptics `06cb:00a2` fingerprint reader
(shown in Windows as *Synaptics WBDI* / *Synaptics Metallica MOH Touch
Fingerprint Reader*). Until now this reader had no Linux support:
`fprintd-enroll` says *"No devices available"* and python-validity does not
work with it. This kit builds a version of
[libfprint](https://gitlab.freedesktop.org/libfprint/libfprint) that supports
it, so more people can test it before it is sent upstream.

It works with your distribution's own fprintd: enrollment from GNOME/KDE
settings, lock screen, login and `sudo`.

## Does my computer have this reader?

Run this in a terminal:

```sh
lsusb | grep 06cb:00a2
```

If a line comes back, you have it. Other Synaptics readers (`06cb:009a`,
`06cb:00bd`, ...) are **not** covered by this kit.

Laptops known to have the `06cb:00a2` reader:

| Laptop | Source | Tested with this driver |
|---|---|---|
| ThinkPad L380 Yoga (20M7, 20M8) | Lenovo driver notes | **Works** (Ubuntu 26.10) |
| ThinkPad L380 (20M5, 20M6) | Lenovo driver notes | not yet |
| ThinkPad S2 3rd Gen (20L1) | Lenovo driver notes | not yet |
| ThinkPad S2 Yoga 3rd Gen (20L2) | Lenovo driver notes | not yet |
| ThinkPad L390 Yoga | user reports | not yet |
| ThinkPad E480 | user reports | not yet |
| ThinkPad E490 | user reports | not yet |
| ThinkPad E580 | user reports | not yet |
| ThinkPad E590 | user reports | not yet |

Other ThinkPads from 2018–2019 may have it too; `lsusb` is the real test.
If yours has it and is not listed, please
[report it](https://github.com/Felipe-Alcazar/fprint-06cb-00a2/issues/new/choose).

## Quick start

```sh
git clone https://github.com/Felipe-Alcazar/fprint-06cb-00a2.git
cd fprint-06cb-00a2
sh check.sh          # checks your computer, changes nothing
./install.sh         # builds and installs (asks for your sudo password)
fprintd-enroll       # enroll a finger (touch the reader ~20 times)
fprintd-verify       # test it
```

No `git`? Click **Code > Download ZIP** on this page, unzip it, open a
terminal in the folder and run the same commands from `sh check.sh` on.

To use the fingerprint for login and `sudo` on Ubuntu/Debian, run
`sudo pam-auth-update --enable fprintd`. You can also enroll from
**Settings > Users > Fingerprint Login** (GNOME) or **System Settings > Users**
(KDE).

## Before you start

- **The reader must have been used by Windows at least once.** Most laptops
  ship that way, so a computer that came with Windows is fine even if you
  later erased it. The driver reuses the pairing Windows set up and **never
  writes to the sensor's memory**, so it cannot damage the reader. Readers
  that never ran under Windows have not been tested.
- If you installed `python-validity` / `open-fprintd`, remove them first.
- Tested on Ubuntu 26.10 (fprintd 1.94). The installer also has the package
  lists for Debian, Fedora and Arch, but those are untested.
- Building takes a few minutes. The installer downloads about 20 MB, plus
  the build packages your system does not have yet.

## What the installer does

1. Installs the build tools and `fprintd`.
2. Downloads and builds libfprint with the driver.
3. Downloads Lenovo's official Windows driver (`r0rgn10w.exe`) and extracts
   the sensor's init block from it. The file is checked by its hash and only
   unpacked; nothing in it is run. That block cannot be redistributed, so
   every computer extracts its own.
4. Installs everything to `/opt/libfprint-00a2` and makes only `fprintd`
   load it. The system libfprint is not touched, and system updates do not
   undo the install.

To remove everything: `./uninstall.sh`. It deletes the prints enrolled with
the test driver, removes the files from `/opt` and puts fprintd back to normal.

## Troubleshooting

| What you see | What to do |
|---|---|
| `check.sh` says the reader was not found | Run `lsusb`. If no `06cb:00a2` line is listed, your laptop has a different reader. |
| `No devices available` after installing | Run `sudo systemctl restart fprintd` and try again. If it still fails, run `./collect-log.sh`. |
| Enrollment keeps asking for the same touch | Lift your finger fully between touches and cover the whole sensor. Small or off-center touches are rejected on purpose. |
| Your finger is not recognized | Enroll again and vary the finger position a little between touches. Then send a report with how many misses you got in 10 tries. |
| The reader worked, then stopped after sleep | Run `./collect-log.sh`, repeat what failed and attach the log to an issue. |

## How to help

[Open a test report](https://github.com/Felipe-Alcazar/fprint-06cb-00a2/issues/new/choose).
It is a short form: laptop model, distribution, whether enroll and verify
worked, and the log from `./collect-log.sh` if something failed. Read the log
before sending it.

**"It works on my laptop" reports help a lot.** Each one goes into the table
above and helps get the driver accepted upstream.

## How it works

The 06cb:00a2 is a "match-on-host" reader: it only takes a picture of the
finger, and the computer does the matching. That is why python-validity,
which relies on the sensor to match, could not support it. The driver builds
on libfprint's `validity` driver, still under review in
[MR !626](https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/626),
which already supports other readers of the same family. The 00a2 part (image
download, enrollment and SIFT + RANSAC matching) lives in the
[`fp-00a2-dev`](https://github.com/Felipe-Alcazar/libfprint/tree/fp-00a2-dev)
branch.

After testing, the plan is to send this support to libfprint upstream so it
reaches distributions without this kit.

The scripts in this kit are MIT licensed. libfprint is LGPL-2.1.
