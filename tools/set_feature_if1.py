#!/usr/bin/env python3
"""
SET/GET Feature reports on iBUYPOWER MK9 IF1 only (vendor/RGB).

Safety defaults:
  - Resolves hidraw by udev (3402:0303, interface 01) — never hard-codes hidrawN
  - Refuses IF0 / boot keyboard
  - DRY-RUN by default (prints packet, does not write)
  - --apply requires --i-understand-risk
  - Built-in presets are small 0x05 probes only (no 520 B 0x06 bulk by default)

Hardware undo: FN+ESC (factory lighting reset)

Examples:
  ./tools/set_feature_if1.py --list-presets
  ./tools/set_feature_if1.py --preset zero6              # dry-run
  ./tools/set_feature_if1.py --preset zero6 --apply --i-understand-risk
  ./tools/set_feature_if1.py --hex 05:01:00:00:00:00 --apply --i-understand-risk
  ./tools/set_feature_if1.py --get 0x06 --get-len 520
"""

from __future__ import annotations

import argparse
import array
import fcntl
import os
import subprocess
import sys
import time
from pathlib import Path

VID = "3402"
PID = "0303"
IF1 = "01"
IF0 = "00"

# hidraw: HIDIOCSFEATURE / HIDIOCGFEATURE — _IOC(_IOC_READ|_IOC_WRITE, 'H', nr, len)
def _HIDIOC(nr: int, length: int) -> int:
    return (3 << 30) | (ord("H") << 8) | nr | (length << 16)


def HIDIOCSFEATURE(length: int) -> int:
    return _HIDIOC(0x06, length)


def HIDIOCGFEATURE(length: int) -> int:
    return _HIDIOC(0x07, length)


# Named first-wave presets (report 0x05 only). See docs/notes/set-hypothesis-01.md
PRESETS: dict[str, bytes] = {
    # Probe A — pipe smoke: all-zero payload after report ID
    "zero6": bytes([0x05, 0x00, 0x00, 0x00, 0x00, 0x00]),
    # Probe B — cmd nibble candidates (only after zero6 is understood)
    "cmd01": bytes([0x05, 0x01, 0x00, 0x00, 0x00, 0x00]),
    "cmd02": bytes([0x05, 0x02, 0x00, 0x00, 0x00, 0x00]),
    "cmd08": bytes([0x05, 0x08, 0x00, 0x00, 0x00, 0x00]),
    "cmd10": bytes([0x05, 0x10, 0x00, 0x00, 0x00, 0x00]),
    "cmd80": bytes([0x05, 0x80, 0x00, 0x00, 0x00, 0x00]),
    # Probe C — brightness-ish second byte (speculative)
    "b1_ff": bytes([0x05, 0x01, 0xFF, 0x00, 0x00, 0x00]),
    "b1_00": bytes([0x05, 0x01, 0x00, 0x00, 0x00, 0x00]),
}


def udev_props(node: str) -> dict[str, str]:
    try:
        out = subprocess.check_output(
            ["udevadm", "info", "-q", "property", "-n", node],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return {}
    props: dict[str, str] = {}
    for line in out.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            props[k] = v
    return props


def resolve_hidraw(interface: str) -> str | None:
    for ent in sorted(Path("/dev").glob("hidraw*")):
        node = str(ent)
        p = udev_props(node)
        if (
            p.get("ID_VENDOR_ID", "").lower() == VID
            and p.get("ID_MODEL_ID", "").lower() == PID
            and p.get("ID_USB_INTERFACE_NUM") == interface
        ):
            return node
    return None


def hex_bytes(data: bytes) -> str:
    return " ".join(f"{b:02x}" for b in data)


def parse_hex(spec: str) -> bytes:
    """Accept '05:01:00:00:00:00' or '05 01 00 00 00 00' or '050100000000'."""
    s = spec.strip().lower().replace("0x", "")
    if ":" in s:
        parts = s.split(":")
    elif " " in s or "," in s:
        parts = s.replace(",", " ").split()
    else:
        if len(s) % 2:
            raise ValueError(f"odd-length hex: {spec!r}")
        parts = [s[i : i + 2] for i in range(0, len(s), 2)]
    return bytes(int(p, 16) for p in parts)


def set_feature(path: str, payload: bytes) -> tuple[bool, str]:
    length = len(payload)
    try:
        fd = os.open(path, os.O_RDWR)
    except OSError as e:
        return False, f"open failed: {e}"
    try:
        buf = array.array("B", payload)
        try:
            # mutate=True so kernel can write back; some drivers ignore
            fcntl.ioctl(fd, HIDIOCSFEATURE(length), buf, True)
            back = bytes(buf)
            note = ""
            if back != payload:
                note = f" (buffer after ioctl: {hex_bytes(back)})"
            return True, f"OK SET len={length}{note}"
        except OSError as e:
            return False, f"SET FAIL errno={e.errno}: {e}"
    finally:
        os.close(fd)


def get_feature(path: str, report_id: int, length: int) -> tuple[bool, str, bytes | None]:
    try:
        fd = os.open(path, os.O_RDWR)
    except OSError as e:
        return False, f"open failed: {e}", None
    try:
        buf = array.array("B", [0] * length)
        buf[0] = report_id & 0xFF
        try:
            fcntl.ioctl(fd, HIDIOCGFEATURE(length), buf, True)
            data = bytes(buf)
            nz = sum(1 for b in data if b)
            return True, f"OK GET len={length} nonzero={nz} head=[{hex_bytes(data[:16])}]", data
        except OSError as e:
            return False, f"GET FAIL errno={e.errno}: {e}", None
    finally:
        os.close(fd)


def main() -> int:
    ap = argparse.ArgumentParser(
        description="MK9 IF1 Feature SET/GET — dry-run by default; FN+ESC to reset lights"
    )
    ap.add_argument("--list-presets", action="store_true", help="List built-in 0x05 presets")
    ap.add_argument("--preset", choices=sorted(PRESETS.keys()), help="Named preset packet")
    ap.add_argument("--hex", help="Raw payload including report ID (e.g. 05:00:00:00:00:00)")
    ap.add_argument(
        "--apply",
        action="store_true",
        help="Actually perform SET (default is dry-run)",
    )
    ap.add_argument(
        "--i-understand-risk",
        action="store_true",
        help="Required with --apply; confirms FN+ESC undo and IF1-only",
    )
    ap.add_argument("--get", type=lambda s: int(s, 0), help="Also GET this report ID after SET")
    ap.add_argument("--get-len", type=int, default=520, help="GET length including report ID")
    ap.add_argument(
        "--get-only",
        action="store_true",
        help="Only GET (no SET); uses --get / --get-len (defaults 0x06 / 520)",
    )
    ap.add_argument(
        "--sleep",
        type=float,
        default=0.0,
        help="Seconds to sleep after SET before optional GET",
    )
    ap.add_argument(
        "--save-get",
        type=Path,
        help="Write GET payload to this path",
    )
    ap.add_argument(
        "--allow-report06-set",
        action="store_true",
        help="Allow SET of report 0x06 (large); default refuse for safety",
    )
    args = ap.parse_args()

    if args.list_presets:
        print("Built-in presets (report 0x05, 6 bytes total):\n")
        for name, payload in PRESETS.items():
            print(f"  {name:8s}  {hex_bytes(payload)}")
        print("\nSee docs/notes/set-hypothesis-01.md")
        return 0

    if1 = resolve_hidraw(IF1)
    if0 = resolve_hidraw(IF0)
    if not if1:
        print("ERROR: no hidraw for 3402:0303 interface 01", file=sys.stderr)
        return 1

    print(f"IF1 (target): {if1}")
    if if0:
        print(f"IF0 (boot, untouched): {if0}")
    rdesc = Path(f"/sys/class/hidraw/{Path(if1).name}/device/report_descriptor")
    if rdesc.exists():
        # sysfs st_size is often 4096; use actual content length
        rdesc_len = len(rdesc.read_bytes())
        print(f"IF1 rdesc size: {rdesc_len} (expect 240)")

    if args.get_only:
        rid = args.get if args.get is not None else 0x06
        ok, msg, data = get_feature(if1, rid, args.get_len)
        print(f"GET id=0x{rid:02x} len={args.get_len}: {msg}")
        if ok and data is not None and args.save_get:
            args.save_get.write_bytes(data)
            print(f"saved {args.save_get}")
        return 0 if ok else 2

    payload: bytes | None = None
    if args.preset:
        payload = PRESETS[args.preset]
        print(f"preset: {args.preset}")
    elif args.hex:
        try:
            payload = parse_hex(args.hex)
        except ValueError as e:
            print(f"ERROR: {e}", file=sys.stderr)
            return 1
    else:
        print("ERROR: specify --preset, --hex, --get-only, or --list-presets", file=sys.stderr)
        return 1

    assert payload is not None
    if len(payload) < 1:
        print("ERROR: empty payload", file=sys.stderr)
        return 1

    rid = payload[0]
    print(f"report_id: 0x{rid:02x}")
    print(f"length:    {len(payload)} (incl. report ID)")
    print(f"payload:   {hex_bytes(payload)}")

    if rid == 0x06 and len(payload) > 8 and not args.allow_report06_set:
        print(
            "ERROR: refusing large report 0x06 SET without --allow-report06-set",
            file=sys.stderr,
        )
        return 1
    if rid not in (0x05, 0x06):
        print(
            f"WARNING: report ID 0x{rid:02x} is not the known Feature map (0x05/0x06)",
            file=sys.stderr,
        )

    if not args.apply:
        print("\nDRY-RUN: no ioctl performed.")
        print("To write: add  --apply --i-understand-risk")
        print("Before apply: start usbmon capture; after: note lights; FN+ESC if weird.")
        return 0

    if not args.i_understand_risk:
        print(
            "ERROR: --apply requires --i-understand-risk "
            "(FN+ESC undo, IF1 only, capture recommended)",
            file=sys.stderr,
        )
        return 1

    # Hard refuse if path somehow equals IF0
    if if0 and os.path.samefile(if1, if0):
        print("ERROR: IF1 resolved same as IF0 — abort", file=sys.stderr)
        return 1

    print("\nAPPLYING SET_FEATURE …")
    t0 = time.monotonic()
    ok, msg = set_feature(if1, payload)
    dt = (time.monotonic() - t0) * 1000
    print(f"result: {msg}  ({dt:.1f} ms)")
    if not ok:
        return 2

    if args.sleep > 0:
        time.sleep(args.sleep)

    if args.get is not None:
        gok, gmsg, data = get_feature(if1, args.get, args.get_len)
        print(f"GET id=0x{args.get:02x}: {gmsg}")
        if gok and data is not None and args.save_get:
            args.save_get.write_bytes(data)
            print(f"saved {args.save_get}")

    print("Done. Observe lights. FN+ESC = factory lighting reset.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
