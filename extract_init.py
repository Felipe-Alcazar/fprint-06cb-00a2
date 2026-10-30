"""Extract the 06cb:00a2 sensor init data from Lenovo's public Windows driver.

The sensor only accepts a hardware-init command that ships inside Lenovo's
driver. It is not redistributed here: this script downloads that driver from
Lenovo, checks it, unpacks it without running anything, and finds the init
data by its SHA-256. Only the hash lives in this source.

Usage: python3 -I extract_init.py OUTPUT_DIR [driver.exe]
Writes OUTPUT_DIR/06cb_00a2/init.bin in the libfprint-validity-data format
(data followed by its HMAC-SHA256).
"""
import glob
import hashlib
import hmac
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request

DRIVER_URL = 'https://download.lenovo.com/pccbbs/mobiles/r0rgn10w.exe'
DRIVER_SHA512 = ('d8c2477905ce53de7a3e4a7eab54f792e8d864313808ad86b80651d1977110e9'
                 '84138bee7049d6c63bf351bc5b2d43d6cb15d7eb21aaec8d2ff46b09205902c9')
DRIVER_DLL = 'synaWudfBioUsb.dll'

# The init command is opcode 0x06 followed by 580 bytes stored in the DLL
# (where the first byte reads 0x00). Identified by hash only.
INIT_SIZE = 581
INIT_SHA256 = '0f3128a1c93b49f0a5162bbad26b22ae02f539ab0668678ea090449922e39674'
INIT_MARKER = b'\x02\x00\x00\x01'  # bytes 1..4 of the command, to find candidates fast

# Integrity key of libfprint-validity-data (not secret, also in the driver).
HMAC_KEY = b'libfprint-validity-data-integrit'


def find_init(dll: bytes) -> bytes:
    i = dll.find(INIT_MARKER)
    while i >= 0:
        cand = b'\x06' + dll[i:i + INIT_SIZE - 1]
        if hashlib.sha256(cand).hexdigest() == INIT_SHA256:
            return cand
        i = dll.find(INIT_MARKER, i + 1)
    sys.exit('init data not found in %s' % DRIVER_DLL)


def extract(driver_path: str = None) -> bytes:
    if shutil.which('innoextract') is None:
        sys.exit('innoextract is needed (Debian/Ubuntu: apt install innoextract)')
    with tempfile.TemporaryDirectory(prefix='fp00a2-driver-') as tmp:
        exe = driver_path or os.path.join(tmp, 'driver.exe')
        if not driver_path:
            print('Downloading %s ...' % DRIVER_URL, flush=True)
            urllib.request.urlretrieve(DRIVER_URL, exe)
        h = hashlib.sha512()
        with open(exe, 'rb') as f:
            for chunk in iter(lambda: f.read(1 << 20), b''):
                h.update(chunk)
        if h.hexdigest() != DRIVER_SHA512:
            sys.exit('the Lenovo driver does not match the expected file')
        out = os.path.join(tmp, 'x')
        os.mkdir(out)
        # innoextract only unpacks; nothing from the driver is executed.
        subprocess.run(['innoextract', '-s', '-d', out, exe], check=True)
        dlls = glob.glob(os.path.join(out, '**', DRIVER_DLL), recursive=True)
        if not dlls:
            sys.exit('%s not found in the driver package' % DRIVER_DLL)
        with open(dlls[0], 'rb') as f:
            return find_init(f.read())


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    data = extract(sys.argv[2] if len(sys.argv) == 3 else None)
    dest = os.path.join(sys.argv[1], '06cb_00a2')
    os.makedirs(dest, exist_ok=True)
    with open(os.path.join(dest, 'init.bin'), 'wb') as f:
        f.write(data)
        f.write(hmac.new(HMAC_KEY, data, hashlib.sha256).digest())
    print('Sensor init data written to %s' % os.path.join(dest, 'init.bin'))


if __name__ == '__main__':
    main()
