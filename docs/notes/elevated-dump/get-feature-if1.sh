#!/bin/bash
# Read-only GET_FEATURE on MK9 interface 1 (vendor). Resolves hidraw by udev, not by number.
set -euo pipefail
OUT="${1:-/home/gigachad/Dev/keyboardproject/docs/notes/elevated-dump}"
mkdir -p "$OUT"
cd "$OUT"

resolve_hidraw_if1() {
  for node in /dev/hidraw*; do
    [ -e "$node" ] || continue
    vend=$(udevadm info -q property -n "$node" 2>/dev/null | sed -n 's/^ID_VENDOR_ID=//p')
    prod=$(udevadm info -q property -n "$node" 2>/dev/null | sed -n 's/^ID_MODEL_ID=//p')
    ifn=$(udevadm info -q property -n "$node" 2>/dev/null | sed -n 's/^ID_USB_INTERFACE_NUM=//p')
    if [ "$vend" = "3402" ] && [ "$prod" = "0303" ] && [ "$ifn" = "01" ]; then
      echo "$node"
      return 0
    fi
  done
  return 1
}

resolve_hidraw_if0() {
  for node in /dev/hidraw*; do
    [ -e "$node" ] || continue
    vend=$(udevadm info -q property -n "$node" 2>/dev/null | sed -n 's/^ID_VENDOR_ID=//p')
    prod=$(udevadm info -q property -n "$node" 2>/dev/null | sed -n 's/^ID_MODEL_ID=//p')
    ifn=$(udevadm info -q property -n "$node" 2>/dev/null | sed -n 's/^ID_USB_INTERFACE_NUM=//p')
    if [ "$vend" = "3402" ] && [ "$prod" = "0303" ] && [ "$ifn" = "00" ]; then
      echo "$node"
      return 0
    fi
  done
  return 1
}

IF1=$(resolve_hidraw_if1) || { echo "ERROR: no hidraw for 3402:0303 IF1"; exit 1; }
IF0=$(resolve_hidraw_if0) || IF0=""

echo "Resolved IF1 (vendor/RGB): $IF1"
echo "Resolved IF0 (boot kb):    ${IF0:-none}"
RDESC_SIZE=$(wc -c < /sys/class/hidraw/$(basename "$IF1")/device/report_descriptor)
echo "IF1 report descriptor size: $RDESC_SIZE (expect 240)"
echo

python3 - "$IF1" "$IF0" <<'PY'
import os, sys, fcntl, array

if1, if0 = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")

def HIDIOCGFEATURE(length):
    return (3 << 30) | (ord("H") << 8) | 0x07 | (length << 16)

def get_feature(path, report_id, length):
    try:
        fd = os.open(path, os.O_RDWR)
    except OSError as e:
        return f"OPEN FAIL errno={e.errno}: {e}"
    try:
        buf = array.array("B", [0] * length)
        buf[0] = report_id
        try:
            fcntl.ioctl(fd, HIDIOCGFEATURE(length), buf, True)
            data = buf.tobytes()
            open(f"feature-if1-id{report_id:02x}-len{length}.bin", "wb").write(data)
            return "OK " + data.hex(" ")
        except OSError as e:
            return f"FAIL errno={e.errno}: {e}"
    finally:
        os.close(fd)

lines = [f"target IF1 {if1} GET_FEATURE only\n"]
for rid, length in [(0x05, 6), (0x05, 9), (0x06, 520), (0x06, 65), (0x06, 9), (0x06, 8)]:
    r = get_feature(if1, rid, length)
    lines.append(f"ID=0x{rid:02X} len={length}: {r}")

if if0:
    lines.append(f"\nboot IF0 {if0} (expect fail — no features):")
    lines.append("  " + get_feature(if0, 0x05, 6))

text = "\n".join(lines) + "\n"
open("get-feature-if1.txt", "w").write(text)
print(text)
PY

# also try python hid module on IF1
python3 - "$IF1" <<'PY' 2>&1 | tee hidapi-get-feature.txt
import sys
try:
    import hid
except Exception as e:
    print("hid import failed", e)
    sys.exit(0)
path = sys.argv[1]
print("opening", path)
d = hid.device()
d.open_path(path.encode() if isinstance(path, str) else path)
for rid, size in [(0x05, 6), (0x06, 520), (0x06, 65)]:
    try:
        # hidapi get_feature_report(report_id, size) — size includes report id byte on some backends
        data = d.get_feature_report(rid, size)
        print(f"hidapi ID=0x{rid:02X} size={size}: OK {bytes(data).hex(' ')}")
        open(f"hidapi-id{rid:02x}-len{size}.bin", "wb").write(bytes(data))
    except Exception as e:
        print(f"hidapi ID=0x{rid:02X} size={size}: FAIL {e}")
d.close()
PY

chown -R gigachad:gigachad "$OUT" 2>/dev/null || true
ls -la "$OUT"
echo "DONE: $OUT"
