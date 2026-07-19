# usbmon FN lighting capture — 2026-07-19

**Pcap:** `captures/fn-lighting-20260719-145150.pcapng` (gitignored, ~710 KB)  
**Interface:** `usbmon3` · duration ~50 s · 6960 frames · 0 drops  
**Keyboard:** bus 3 device **8** · `3402:0303` · IF0 EP `0x81`, IF1 EP `0x82`

Post-reboot: user is in `usbmon` group; `/dev/usbmon3` readable without root.

---

## Executive result

| Question | Answer |
|----------|--------|
| Do FN lighting changes generate **control** transfers (GET/SET Feature) to the keyboard? | **No** |
| Any bulk traffic to the keyboard? | **No** |
| Keyboard traffic during the window? | **Interrupt IN only** (64 frames, device address 8) |
| Does GET mirror FN state? | Not re-tested in this step (needs sudo on hidraw); prior idle GET 0x06 was all zeros |

**Conclusion:** FN backlight / color / mode / brightness are **MCU-local**. The host is not on the lighting control path for stock FN shortcuts. A software RGB path must still exist as **host-initiated Feature reports** (IF1 `0x05` / `0x06`) if the firmware implements one — it will not be reverse-engineered by watching FN alone.

**User confirmation (same session):** Keyboard colors and FN lighting controls **worked normally** during/around the capture window (lights visibly changed). So this is not a “user didn’t press anything” false negative — on-device lighting works while the USB bus shows no RGB control path.

---

## Traffic breakdown (whole bus)

| Transfer type | Count | Notes |
|---------------|------:|-------|
| Interrupt (`0x01`) | 6920 | Mostly other devices (esp. address 4 mouse) |
| Control (`0x02`) | 36 | **Devices 1, 3, 11 only** — hub suspend/BT noise, not keyboard |
| Bulk (`0x03`) | 4 | Device 11 only |

Control recipients in this capture: **never device 8**.

---

## Device 8 (MK9) interrupt payloads

All keyboard activity clustered ~t=37.9 s–46.0 s (8 bursts, ~1.5–2 s apart).

### EP `0x81` (boot keyboard, IF0)

| Payload (hex) | Count | Meaning |
|---------------|------:|---------|
| `00 00 00 00 00 00 00 00` | 8 | Empty boot report (no modifiers / no keys) |

No non-zero scancodes observed.

### EP `0x82` (IF1 multi)

| Payload (hex) | Count | Report ID | Meaning |
|---------------|------:|-----------|---------|
| `02 00 00` | 8 | `0x02` | Consumer control empty |
| `01 00` | 8 | `0x01` | System control empty |
| `04` + 15×`00` | 8 | `0x04` | Extra-key bitmap empty |

No vendor report `0x03` / `0x05` / `0x06` on the interrupt pipe. No non-zero key/media bits in captured completes.

**Interpretation:** Either FN lighting combos are fully swallowed on-device (only empty multi-collection “noise” / release frames reach the host), or key-down payloads were not present in this window. Either way, **no RGB protocol bytes** appeared.

---

## What this does *not* disprove

- Host software can still drive lights via **SET_FEATURE** on `0x05` / `0x06` (never exercised by FN).
- A Windows-only companion app (if one exists for this OEM PCB) would be the gold capture target.
- OpenRGB Sinowealth-family related art remains **family art only** — do not blind-replay.

---

## Recommended next steps

1. **Optional:** Re-GET Feature `0x06` after deliberate FN color change (sudo + `get-feature-if1.sh`) — expect still zeros if GET does not mirror MCU lighting state.
2. **udev rule** for IF1 hidraw (`3402`/`0303`, interface 01 only) so GET/SET does not need full root.
3. **Host protocol discovery without FN:**
   - Search for any official/iBUYPOWER/Redragon/Eastern Times app that talks to `3402:0303` or ET-7449.
   - Windows USBPcap while that app runs (best).
   - Or carefully designed **single-packet SET** experiments on `0x05` with usbmon running + **FN+ESC** undo — only after a written hypothesis.
4. Do **not** treat this pcap as a protocol corpus for RGB writes.

---

## Reproduce

```bash
cd ~/Dev/keyboardproject
# confirm: groups | grep usbmon ; lsusb -d 3402:0303
dumpcap -i usbmon3 -a duration:50 -w captures/fn-lighting-$(date +%Y%m%d-%H%M%S).pcapng
# while running: FN+Space, FN+RCtrl (color), FN+↑/↓, FN+RAlt (mode)
```

Analysis filters used:

```bash
tshark -r captures/fn-lighting-….pcapng -Y 'usb.device_address == 8'
tshark -r … -Y 'usb.transfer_type == 0x02'   # control — none to dev 8
```
