# Fedora read-only hardware sweep — iBUYPOWER MK9

**Date:** 2026-07-19T14:35:24-07:00  
**Host:** `forge-fedora` · Linux 7.1.3-201.fc44.x86_64  
**Scope:** Read-only enumeration only. No SET_FEATURE / Output / firmware writes.  
**Raw dump dir:** `docs/notes/fedora-readonly-sweep-20260719-143524/`

---

## Executive summary

| Item | Finding |
|------|---------|
| Device present | **Yes** — USB FS 12 Mbps, bus 3 dev 8 |
| VID:PID | **`3402:0303`** · bcdDevice **`20.02`** |
| Strings | Mfr **`BY Tech`** · Product **`American Future BY iBUYPOWER MK9 Mechanical Keyboard`** · **no serial** |
| Interfaces | **2** HID (`usbhid` / `hid-generic`) |
| RGB-relevant path | **Interface 1** · Feature reports **0x05** (6 B) and **0x06** (520 B) · **hidraw number is unstable** — resolve by `ID_USB_INTERFACE_NUM=01` (currently often `hidraw4`, was `hidraw5` earlier) |
| OpenRGB | **Does not list this keyboard** (only ENE DRAM on this host) |
| Public protocol | Still none; this dump is the best device-specific HID map so far |
| Blocked without elevation | GET_FEATURE on hidraw, `usbhid-dump`, raw `/dev/bus/usb/*` open (need root or udev rules) |

---

## USB identity

```
Bus 003 Device 008: ID 3402:0303 BY Tech American Future BY iBUYPOWER MK9 Mechanical Keyboard
```

| Field | Value |
|-------|--------|
| Sysfs | `/sys/devices/pci0000:80/0000:80:14.0/usb3/3-5/3-5.1` |
| Topology | xHCI → Realtek hub `0bda:5409` port 1 → keyboard |
| Speed | Full-speed **12 Mbit/s** |
| Power | Bus-powered, **500 mA**, remote wakeup (`bmAttributes 0xa0`) |
| Class | Device class 0 (interface-defined) |
| Config | 1 config, **2 interfaces**, wTotalLength `0x003b` |

Sibling on same hub (not this device): gaming mouse `18f8:0fc0`.

---

## Interfaces & endpoints

### Interface 0 — boot keyboard (typing)

| | |
|--|--|
| Class | HID Boot Keyboard (`03/01/01`) |
| Driver | `usbhid` → `hid-generic` |
| HID device | `0003:3402:0303.0005` |
| hidraw | **`/dev/hidraw4`** (mode `600` root) |
| EP | **IN `0x81`**, interrupt, **8 bytes**, 1 ms |
| Report descriptor | **67 bytes** (standard 8-byte boot keyboard + LED output) |
| Linux input | `input6` → **`/dev/input/event5`** (keyboard) |
| udev by-id | `…MK9_Mechanical_Keyboard-event-kbd` / `…-hidraw` |

**Do not target this interface for RGB.** Keep free for typing.

### Interface 1 — multi-collection / vendor (RGB target)

| | |
|--|--|
| Class | HID non-boot (`03/00/00`) |
| Driver | `usbhid` → `hid-generic` |
| HID device | `0003:3402:0303.0006` |
| hidraw | **`/dev/hidraw5`** (mode `600` root) |
| hiddev | **`/dev/usb/hiddev3`** (`usbmisc/hiddev3`) |
| EP | **IN `0x82`**, interrupt, **16 bytes**, 1 ms |
| Report descriptor | **240 bytes** (multiple report IDs) |

Linux input nodes on this interface:

| Node | Name | Role |
|------|------|------|
| event6 | … System Control | Power/sleep/wake (report 0x01) |
| event7 | … Consumer Control | Media keys (report 0x02) |
| event8 | … Keyboard | Extra bitmap keyboard (report 0x04) |
| event9 | … Mouse | 5-button + wheel (report 0x07) |

Kernel log:

```
hid-generic 0003:3402:0303.0006: input,hiddev99,hidraw5: USB HID v1.11 Keyboard […] on …/input1
```

---

## Report map (decoded from sysfs)

Full decode: `fedora-readonly-sweep-20260719-143524/08-rdesc-decoded.txt`  
Binaries: `rdesc-if0-boot-keyboard.bin`, `rdesc-if1-vendor-multi.bin`

### IF0 — no Report IDs (boot)

| Direction | Size | Content |
|-----------|------|---------|
| Input | 8 B | Modifiers + reserved + 6 keycodes |
| Output | 1 B | 5 LED bits + pad (Num/Caps/Scroll…) |

### IF1 — report IDs (critical)

| ID | Type | Payload (excl. ID) | Usage page | Notes |
|----|------|--------------------|------------|--------|
| **0x01** | Input | 1 B | Generic Desktop System Control | Power/sleep/wake bits |
| **0x02** | Input | 2 B | Consumer | Media / consumer usage |
| **0x03** | Input | 3 B | **Vendor `0xFF00`** | Usage `0x2F` — unknown vendor IN |
| **0x04** | Input | 15 B | Keyboard | Bitmap keys 0x04–0x70 (NKRO-style) |
| **0x05** | **Feature** | **5 B** | **Vendor `0xFF00`** | Usages 1–2 · **6 B total w/ ID** — **prime small control report** |
| **0x06** | Input + **Feature** | IN 7 B · **Feature 519 B** | **Vendor `0xFF00`** | **520 B feature w/ ID** — **likely bulk config / per-key / mode blob** |
| **0x07** | Input | ~8 B structured | Mouse + AC Pan | Buttons, X/Y, wheel, consumer 0x238 |

### Why 0x05 / 0x06 matter

- Only **Feature** reports on the vendor page → classic host↔MCU config channel (GET/SET_FEATURE).  
- **0x05 @ 6 bytes** matches the size class used by some Sinowealth-family small command packets (OpenRGB related art used report `0x05` on *other* VIDs — **not proof of sameness**).  
- **0x06 @ 520 bytes** is large enough for per-key RGB or full lighting tables.  
- Interrupt EP is only **16 B IN** — large RGB state is almost certainly **control transfers (Feature)**, not interrupt streaming.

---

## OpenRGB smoke test

```
openrgb --list-devices
```

Listed: **ENE DRAM ×2 only**.  
**No `3402:0303` / BY Tech / MK9.** Confirms no stock controller for this PID in this OpenRGB build (0.9+).

---

## Permissions / tooling gaps (next session)

| Need | Status |
|------|--------|
| Read report descriptors via sysfs | **Done** (no root) |
| GET_FEATURE 0x05/0x06 | **Blocked** — hidraw `600 root`; `sudo -n` needs password |
| `usbhid-dump` | **Blocked** — needs write on `/dev/bus/usb/003/008` |
| Wireshark/tshark | Installed; user in `wireshark` group; dumpcap caps OK |
| usbmon nodes | `/dev/usbmon3` is `root:usbmon` **mode 640** — user **not** in `usbmon` group → may need `usermod -aG usbmon` + re-login or run capture as root |
| Python `hid` | Not installed (`hidapi` RPM lib only; no `hidapi-devel` / py binding) |
| Ghidra | `~/tools/ghidra_12.0.4_PUBLIC/ghidraRun` |

Suggested udev (for later, not applied): allow plugdev/uaccess on `hidraw` for `3402/0303` interface 1 only — still prefer **not** grabbing IF0.

---

## Safety reminders (unchanged)

1. Prefer **hidraw5 / IF1** only for RGB experiments.  
2. No firmware/ISP.  
3. FN+ESC = hardware lighting reset.  
4. Do **not** replay OpenRGB Sinowealth keyboard packets blind (`0x258A` family; detectors disabled after bricks).  
5. Next active step after permissions: **GET_FEATURE dump** of 0x05 and 0x06 at rest, then **usbmon capture while FN changes lights** (host may see nothing if FN is pure MCU-local — still valuable negative result).

---

## Artifact index

Directory: `docs/notes/fedora-readonly-sweep-20260719-143524/`

| File | Content |
|------|---------|
| `01-lsusb-overview.txt` | lsusb + tree |
| `02-lsusb-verbose.txt` | Full USB config (HID report body unavailable without device open) |
| `03-sysfs-usb.txt` | Sysfs device/interfaces |
| `04-usb-descriptors.*` | Raw config descriptors |
| `05-endpoints.txt` | ep_81 / ep_82 attrs |
| `06-hid-full.txt` | HID devices, inputs, rdesc hex |
| `07-hidraw-map.txt` | All hidraw on system |
| `08-rdesc-decoded.txt` | Full hierarchical decode |
| `09-udev.txt` | udevadm walks |
| `10-dmesg.txt` | Kernel attach log |
| `11-openrgb.txt` | Device list |
| `12-usbhid-dump.txt` | Denied without root |
| `13-get-feature-readonly.txt` | Denied without root |
| `14-tooling-capture-readiness.txt` | Tool paths / caps |
| `15-hiddev.txt` | hiddev3 mapping |
| `16-input-nodes.txt` | event5–9 |
| `rdesc-if0-*.bin/hex` | Boot keyboard descriptor |
| `rdesc-if1-*.bin/hex` | Vendor multi-collection descriptor |

---

## One-line status for CONTINUE.md

> Fedora read-only sweep complete: MK9 `3402:0303` mapped; RGB candidates are IF1 Feature reports **0x05 (6 B)** and **0x06 (520 B)** on **hidraw5**; OpenRGB does not see the board; GET_FEATURE/usbhid-dump need root or udev.
