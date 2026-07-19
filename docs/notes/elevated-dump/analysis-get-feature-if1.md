# GET_FEATURE on IF1 — results (2026-07-19)

## Resolution

| | |
|--|--|
| IF1 (vendor) | `/dev/hidraw4` · rdesc **240 B** |
| IF0 (boot) | `/dev/hidraw5` · rdesc 67 B |
| Method | `HIDIOCGFEATURE` via hidraw (read-only) |

`hidraw` numbers remain unstable; always resolve by `ID_USB_INTERFACE_NUM=01`.

## Results table

| Report | Length | Result | Payload |
|--------|--------|--------|---------|
| **0x05** | 6, 9 | **EPIPE (32)** | GET not accepted (or wrong for this firmware) |
| **0x06** | 520, 65, 9, 8 | **OK** | **All `0x00`** (including byte 0) |
| IF0 any | — | EPIPE | Expected (no Feature reports) |

Binaries: `feature-if1-id06-len{520,65,9,8}.bin` — each is pure zero; nonzero count = 0.

## Interpretation

### Report 0x05 (5 data bytes + ID → 6 B total)

- Declared as **Feature** on vendor page `0xFF00`.
- **GET STALLs** → firmware may treat it as **SET-only** (common for “command” reports), or GET needs a prior handshake we do not know yet.
- **Do not spam SET** until we have a capture or a reasoned packet layout.
- Size class (6 B) matches small command packets in some OEM/Sinowealth-family controllers (related art only).

### Report 0x06 (519 data + ID → 520 B)

- GET **succeeds** at several lengths → control pipe accepts GET for this ID.
- Returned buffer is **all zeros**, including index 0. A real echo of the report ID would usually put **`0x06` in byte 0**. Possible meanings:
  1. Device returns a zeroed feature page (no host-visible lighting state).
  2. Firmware only fills 0x06 after a **command/SET** (write-then-read pattern).
  3. Kernel/ioctl path succeeds without a useful device payload (less likely if USB completed; next probe should log **ioctl return length**).
- Large size fits **per-key / mode table** style blobs once we know how to fill it.

### Python `hid` under sudo

```
hid import failed No module named 'hid'
```

Root’s Python does not see `~/.local` user packages. Fix when re-testing hidapi:

```bash
sudo PYTHONPATH=/home/gigachad/.local/lib/python3.14/site-packages \
  /home/gigachad/Dev/keyboardproject/docs/notes/elevated-dump/get-feature-if1.sh
```

Or: `pip install hid` system-wide (less ideal).

## What this does / does not prove

| Proven | Not proven |
|--------|------------|
| IF1 is the correct control surface | Byte layout of RGB commands |
| 0x06 is a valid GET Feature ID | That 0x06 currently holds lighting state |
| 0x05 is not GETtable in idle state | That 0x05 is RGB (likely, not confirmed) |
| Boot IF0 has no features | Protocol compatibility with OpenRGB Sinowealth |

## Recommended next experiments (still careful)

1. ~~**Re-login** so `usbmon` group applies~~ — **done** post-reboot.
2. ~~**usbmon FN capture**~~ — **done** (`docs/notes/fn-usbmon-capture-20260719.md`): **no control transfers**; FN is **MCU-local**. Host RGB path must be software-driven Feature reports, not FN.
3. **GET 0x06 again after FN changes** (same script). If still all zeros → GET does not mirror FN state without a prior command.
4. Optional: improve script to print **ioctl return value** (bytes transferred); udev rule for IF1 hidraw.
5. Only later: minimal **SET_FEATURE** experiments on 0x05 with capture running — one bit at a time, FN+ESC as undo. No OpenRGB Sinowealth blind replay. Prefer companion-app capture (e.g. Windows + any OEM/HYTE software that claims this board) if available.

## Artifact list

- `get-feature-if1.txt` — full log  
- `feature-if1-id06-len*.bin` — zero-filled GETs  
- `usbhid-dump.txt` — descriptors  
- `get-feature-if1.sh` — resolver script  
