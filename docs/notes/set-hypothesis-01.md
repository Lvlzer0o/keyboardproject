# SET hypothesis 01 — first host writes (Fedora)

**Date:** 2026-07-19  
**Tool:** [`tools/set_feature_if1.py`](../../tools/set_feature_if1.py)  
**Target:** IF1 only · Feature report **0x05** · 6 bytes total (ID + 5 data)  
**Undo:** **FN+ESC**  
**Constraint:** No OpenRGB Sinowealth keyboard packet replay (`0x258A` family).

---

## Why 0x05 first

| Evidence | Implication |
|----------|-------------|
| Descriptor: Feature, vendor `0xFF00`, **5 data bytes** | Small command channel |
| GET always **EPIPE** | Likely **SET-only** command report |
| GET 0x06 always zeros; FN is MCU-local | Host path is write-driven |
| 0x06 is **520 B** | Bulk table — do not spam until command vocabulary exists |

Layout (HID):

```text
byte0  Report ID = 0x05
byte1  data[0]   ← primary candidate for "command"
byte2  data[1]   ← arg / value
byte3  data[2]
byte4  data[3]
byte5  data[4]
```

Descriptor usages 1–2 on the 5 bytes are opaque (vendor). Treat as **opaque command register**, not proven RGB.

---

## Probe ladder (one step at a time)

Always: **usbmon capture running** · one packet · watch lights · log result · FN+ESC if weird.

### Probe A — pipe smoke (`zero6`)  ← **approve first**

```text
05 00 00 00 00 00
```

| Outcome | Interpretation |
|---------|----------------|
| SET **OK**, lights **unchanged** | Control pipe accepts SET; zeros likely no-op / ignored |
| SET **OK**, lights **change** | Zeros mean something (off? reset?) — stop and document |
| SET **EPIPE** / fail | SET also rejected for 0x05, or wrong node — stop, recheck IF1 |
| Keyboard **stops typing** | Should not happen (IF1 only); unplug/replug; do not continue SETs |

**Goal of A:** prove host→device Feature SET works without decoding color yet.

### Probe B — single command byte (only after A is boring/safe)

One bit/byte at a time, others zero:

| Preset | Packet | Guess (weak) |
|--------|--------|----------------|
| `cmd01` | `05 01 00 00 00 00` | command = 1 |
| `cmd02` | `05 02 00 00 00 00` | command = 2 |
| `cmd08` | `05 08 00 00 00 00` | power-of-two flag |
| `cmd10` | `05 10 00 00 00 00` | |
| `cmd80` | `05 80 00 00 00 00` | |

Do **not** run the whole table in a loop. One preset per capture segment.

### Probe C — later

Vary byte2 with a fixed cmd that did something.  
Only then consider **0x06** SET with a structured blob + `--allow-report06-set`.

---

## Capture procedure (Fedora)

```bash
cd ~/Dev/keyboardproject

# Terminal 1 — capture bus 3 (confirm with lsusb -d 3402:0303 / lsusb -t)
mkdir -p captures
dumpcap -i usbmon3 -w captures/set-probeA-$(date +%Y%m%d-%H%M%S).pcapng

# Terminal 2 — dry-run first
./tools/set_feature_if1.py --preset zero6

# When ready to write (capture still running):
./tools/set_feature_if1.py --preset zero6 --apply --i-understand-risk

# Optional immediate GET of big feature (expect zeros still)
./tools/set_feature_if1.py --get-only --get 0x06 --get-len 520
```

Stop dumpcap after the probe. Filter:

```bash
tshark -r captures/set-probeA-….pcapng -Y 'usb.device_address == 8 && usb.transfer_type == 0x02'
```

Expect **SET_REPORT** / class request to interface 1 if the ioctl reached the wire.

---

## Explicit non-goals for probe A

- Not matching Redragon GUI packet dumps we do not have  
- Not writing 520-byte `0x06` tables  
- Not using OpenRGB “EVision / Sinowealth keyboard” profiles  
- Not opening IF0  

---

## Result log (fill in)

| Time | Preset / hex | SET result | Light change | Notes / pcap |
|------|--------------|------------|--------------|--------------|
| 2026-07-19 15:04 | `zero6` `05 00 00 00 00 00` | **OK** | **No change** | typing OK; echo in GET 0x06 — `probe-a-zero6/` |
| 2026-07-19 15:05 | `cmd01` `05 01 00 00 00 00` | **OK** | **Maybe faster animation?** (unconfirmed) | GET 0x06 echoes `05 01…` — `probe-b-cmd01/` |
| 2026-07-19 15:07 | *(GET only after FN solid red)* | — | baseline solid red | GET still `05 01…` — **does not mirror FN color** — `probe-c-baseline-red/` |
| 2026-07-19 15:07 | `cmd02` `05 02 00 00 00 00` | **OK** | **No change** (still solid red) | GET echoes `05 02…` — `probe-c-cmd02/` |
| 2026-07-19 15:08 | `05 03 00 ff 00 00` | **OK** | *user to confirm* | color-shaped (cmd=3, G=255); echo includes `ff` — `probe-d-cmd03-green/` |
| | | | | |

---

## Approval gate

**Probe A applied and accepted on the wire.** Confirm lights/typing, then Probe B (`cmd01`, …) one at a time under capture.
