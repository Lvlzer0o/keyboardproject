#!/usr/bin/env bash
# Start usbmon capture, run a set_feature_if1.py invocation, stop capture.
# Default is dry-run (safe). Pass through extra args after -- .
#
# Examples:
#   ./tools/capture_set_probe.sh -- --preset zero6
#   ./tools/capture_set_probe.sh -- --preset zero6 --apply --i-understand-risk
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p captures

BUS=""
# Find bus for 3402:0303
while read -r line; do
  if [[ "$line" =~ Bus\ ([0-9]+)\ Device.*3402:0303 ]]; then
    BUS="${BASH_REMATCH[1]}"
    # strip leading zeros
    BUS=$((10#$BUS))
    break
  fi
done < <(lsusb -d 3402:0303 2>/dev/null || true)

if [[ -z "$BUS" ]]; then
  echo "ERROR: keyboard 3402:0303 not found (lsusb)" >&2
  exit 1
fi

MON="usbmon${BUS}"
if [[ ! -r "/dev/$MON" ]]; then
  echo "ERROR: cannot read /dev/$MON (usbmon group?)" >&2
  exit 1
fi

# Drop leading "--" if present (common when invoking: script -- args...)
if [[ "${1:-}" == "--" ]]; then
  shift
fi

STAMP=$(date +%Y%m%d-%H%M%S)
PCAP="captures/set-probe-${STAMP}.pcapng"
echo "Keyboard on bus $BUS → capture $MON → $PCAP"
echo "Args to set tool: $*"

dumpcap -i "$MON" -w "$PCAP" &
DPID=$!
sleep 0.5
cleanup() {
  if kill -0 "$DPID" 2>/dev/null; then
    kill -INT "$DPID" 2>/dev/null || true
    wait "$DPID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# small settle so first URBs are in file
sleep 0.3
set +e
"$ROOT/tools/set_feature_if1.py" "$@"
RC=$?
set -e
sleep 0.5
cleanup
trap - EXIT

echo
echo "pcap: $PCAP  (set exit=$RC)"
echo "Quick control URB peek (device may not be 8 — check lsusb):"
DEV=$(lsusb -d 3402:0303 | sed -n 's/.*Device \([0-9]*\):.*/\1/p' | head -1)
DEV=$((10#$DEV))
echo "  tshark -r $PCAP -Y 'usb.device_address == $DEV && usb.transfer_type == 0x02'"
tshark -r "$PCAP" -Y "usb.device_address == $DEV && usb.transfer_type == 0x02" 2>/dev/null | head -40 || true
# Also show any SET_REPORT / class interface requests
tshark -r "$PCAP" -Y "usb.device_address == $DEV" -T fields \
  -e frame.number -e usb.transfer_type -e usb.endpoint_address \
  -e usb.bmRequestType -e usb.setup.bRequest -e usb.setup.wValue \
  -e usb.setup.wIndex -e usb.setup.wLength -e usb.capdata 2>/dev/null | head -40 || true
exit "$RC"
