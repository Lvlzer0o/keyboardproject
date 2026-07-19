#!/usr/bin/env bash
# Install IF1-only udev rule, verify access, GET_FEATURE before/after FN color change.
#
# Run in a real terminal (needs your sudo password):
#   cd ~/Dev/keyboardproject
#   ./docs/notes/elevated-dump/install-udev-and-get-after-fn.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
RULE_SRC="$ROOT/docs/notes/udev/99-mk9-if1-hidraw.rules"
RULE_DST="/etc/udev/rules.d/99-mk9-if1-hidraw.rules"
OUT="$ROOT/docs/notes/elevated-dump/post-fn-get-$(date +%Y%m%d-%H%M%S)"
GET_SCRIPT="$ROOT/docs/notes/elevated-dump/get-feature-if1.sh"
mkdir -p "$OUT"

resolve_if() {
  local want_if="$1"
  for node in /dev/hidraw*; do
    [ -e "$node" ] || continue
    vend=$(udevadm info -q property -n "$node" 2>/dev/null | sed -n 's/^ID_VENDOR_ID=//p')
    prod=$(udevadm info -q property -n "$node" 2>/dev/null | sed -n 's/^ID_MODEL_ID=//p')
    ifn=$(udevadm info -q property -n "$node" 2>/dev/null | sed -n 's/^ID_USB_INTERFACE_NUM=//p')
    if [ "$vend" = "3402" ] && [ "$prod" = "0303" ] && [ "$ifn" = "$want_if" ]; then
      echo "$node"
      return 0
    fi
  done
  return 1
}

user_can_rdwr() {
  python3 -c "import os,sys; os.open(sys.argv[1], os.O_RDWR)" "$1" 2>/dev/null
}

summarize_bins() {
  local dest="$1"
  local label="$2"
  python3 - "$dest" "$label" <<'PY'
import sys
from pathlib import Path
dest, label = Path(sys.argv[1]), sys.argv[2]
print(f"--- summary ({label}) ---")
for p in sorted(dest.glob("feature-if1-id*.bin")):
    data = p.read_bytes()
    nz = sum(1 for b in data if b)
    print(f"{p.name}: len={len(data)} nonzero={nz} head16=[{data[:16].hex(' ')}]")
log = dest / "get-feature-if1.txt"
if log.exists():
    print(log.read_text())
PY
}

echo "Artifacts directory: $OUT"
echo

echo "=== 1) Install udev rule (IF1 only) ==="
if [ ! -f "$RULE_SRC" ]; then
  echo "ERROR: missing $RULE_SRC" >&2
  exit 1
fi
sudo cp "$RULE_SRC" "$RULE_DST"
sudo udevadm control --reload-rules
sudo udevadm trigger -s hidraw
sleep 1
echo "Installed: $RULE_DST"

echo
echo "=== 2) Device nodes ==="
IF1=$(resolve_if 01) || { echo "ERROR: no IF1 hidraw for 3402:0303 — is keyboard plugged in?" >&2; exit 1; }
IF0=$(resolve_if 00 || true)
echo "IF1 (vendor/RGB): $IF1"
ls -l "$IF1"
if [ -n "${IF0:-}" ]; then
  echo "IF0 (boot kb):    $IF0"
  ls -l "$IF0"
fi

USE_SUDO=0
if user_can_rdwr "$IF1"; then
  echo "  user RDWR open OK on IF1"
else
  echo "  user RDWR open FAIL on IF1 — will use sudo for GET"
  echo "  (rule is installed; a keyboard unplug/replug or re-login often activates uaccess)"
  USE_SUDO=1
fi
if [ -n "${IF0:-}" ]; then
  if user_can_rdwr "$IF0"; then
    echo "  WARNING: user can open IF0 (boot) — unexpected; check udev rule match"
  else
    echo "  IF0 remains non-user-writable (good)"
  fi
fi

get_probe() {
  local label="$1"
  local dest="$OUT/$label"
  mkdir -p "$dest"
  echo
  echo "=== GET_FEATURE ($label) ==="
  if [ "$USE_SUDO" = "1" ]; then
    sudo "$GET_SCRIPT" "$dest"
  else
    "$GET_SCRIPT" "$dest"
  fi
  summarize_bins "$dest" "$label"
}

get_probe "01-before-fn"

echo
echo "============================================================"
echo "  CHANGE LIGHTING ON THE KEYBOARD NOW:"
echo "    • FN + Right Ctrl  — cycle colors several times"
echo "    • FN + ↑ / ↓       — brightness"
echo "    • FN + Right Alt   — change mode once"
echo "    • Leave lights ON with a non-default look"
echo "  Avoid FN+ESC unless lights go weird."
echo "============================================================"
echo
read -r -p "Press Enter when lighting is changed... "

get_probe "02-after-fn"

echo
echo "=== Diff before vs after ==="
python3 - "$OUT" <<'PY'
from pathlib import Path
import sys
out = Path(sys.argv[1])
a, b = out / "01-before-fn", out / "02-after-fn"
for pa in sorted(a.glob("feature-if1-id*.bin")):
    pb = b / pa.name
    if not pb.exists():
        print(f"  MISSING after: {pa.name}")
        continue
    da, db = pa.read_bytes(), pb.read_bytes()
    if da == db:
        nz = sum(1 for x in da if x)
        print(f"  SAME  {pa.name}  (len={len(da)} nonzero={nz})")
    else:
        n = min(len(da), len(db))
        diffs = [(i, da[i], db[i]) for i in range(n) if da[i] != db[i]]
        if len(da) != len(db):
            print(f"  DIFFER {pa.name}: lens {len(da)} vs {len(db)}, {len(diffs)} byte diffs in overlap")
        else:
            print(f"  DIFFER {pa.name}: {len(diffs)} bytes differ")
        for i, x, y in diffs[:32]:
            print(f"    @{i}: 0x{x:02x} -> 0x{y:02x}")
        if len(diffs) > 32:
            print(f"    ... +{len(diffs) - 32} more")
print()
print(f"All artifacts under: {out}")
PY
