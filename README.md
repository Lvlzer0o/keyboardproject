# iBUYPOWER MK9 RGB — Research & Control Project

Safe, reversible research toward **user-mode RGB control** for the iBUYPOWER MK9 mechanical keyboard — **not** a Windows kernel driver, and **not** a firmware flash project (by design).

> **Status:** Research / planning. No protocol implementation yet.  
> **Goal:** A desktop app that can change RGB (and related lighting settings) without replacing system drivers or risking a bricked board.

**Resuming after a reboot / on another OS?** Start here → **[CONTINUE.md](CONTINUE.md)**

---

## Device identity

| Layer | Value |
|--------|--------|
| **Marketing name** | American Future BY iBUYPOWER **MK9** Mechanical Keyboard |
| **On-device label** | iBUYPOWER · MK9 RGB Mechanical Keyboard · **Model No. ET-7449** · Made in China |
| **USB VID:PID** | `0x3402` : `0x0303` (revision `2002` observed) |
| **Windows bus string** | `American Future BY iBUYPOWER MK9 Mechanical Keyboard` |
| **What Windows shows** | Generic HID Keyboard / USB Composite Device (stock HID stack) |
| **OEM / family** | **Eastern Times Technology Co., Ltd** ecosystem; iBUYPOWER has publicly collaborated with **Redragon** on the MK9 line. Compliance docs list **ET-7449** alongside Redragon **K737B-RGB-PRO** (same model-number family; variants may differ — do not assume identical PCB/wireless layout). |

### How we identified it

1. Windows PnP / WMI enumeration of HID keyboards  
2. USB **bus-reported device description** (not just the generic “HID Keyboard Device” name)  
3. Physical **back-label** photo (`docs/assets/keyboard-back-label.png`) with model **ET-7449**  
4. Manual / shortcut sheet photo (`docs/assets/manual-shortcuts.png`)  
5. Web / compliance hits for ET-7449 → Eastern Times + Redragon collab context  

### Related USB device (not this keyboard)

| Device | VID:PID | Notes |
|--------|---------|--------|
| Generic “USB Gaming Mouse” (Maxxter-style) | `0x18F8` : `0x0FC0` | Exposes a keyboard interface for side/media buttons. **Not** the MK9. |

---

## Hardware / HID layout (Windows)

The MK9 is a **USB composite HID** device. Observed interfaces/collections include:

- Standard **keyboard** (typing)  
- **Consumer control** (media keys)  
- **System controller**  
- **Vendor-defined** HID collections (typical home for RGB / config traffic)  
- A small **mouse** collection (common on gaming boards)  

**Important:** RGB work should target the **vendor-defined** collection(s), not the boot keyboard interface. That keeps typing independent of any control software.

Also seen in registry history on the same machine: `VID_3402` / `PID_0200` (related or previously connected device — not confirmed as current).

---

## Stock features (from manual / back sticker)

Lighting and helpers are primarily **on-device via FN**, which matches “prebuilt accessory board with little or no first-party PC software.”

### Backlight / RGB (FN)

| Shortcut | Function |
|----------|----------|
| FN + ALT (Right) | Change backlight modes (16 modes) |
| FN + CTRL (Right) | Change LED color |
| FN + ↑ / ↓ | Brightness |
| FN + ← / → | Effect speed |
| FN + Space | Backlight on/off |
| FN + ESC | **Factory default reset** (hardware undo) |
| FN + Caps Lock | Full white |
| FN + Backspace | Customize key LED mode (per-key; see below) |

### Other FN functions (high level)

- WIN lock: FN + Win  
- Home / End: FN + O / P  
- Scroll Lock / Pause: FN + `[` / `]`  
- Media / desktop helpers on FN + F1–F12 (My Computer, Calculator, media transport, mute, volume, email, etc.)

Exact tables are preserved in:

- `docs/assets/manual-shortcuts.png`  
- `docs/assets/keyboard-back-label.png`  
- `docs/notes/custom-mode-fn-backspace.md` — **discovered** custom-mode behavior  

### Custom mode (FN + Backspace) — discovered

While in custom mode, **each keypress on a key** advances **that key** through a fixed palette (not free RGB):

**red → green → yellow → blue → purple → turquoise → white → off** → (repeat).

**Save / exit:** **FN + Backspace** again. Multi-slot memory (if any) is unknown. Full lighting reset: **FN+ESC**.  

---

## Project idea & design principles

### What we want

A **software application** that can control RGB (v1 scope still open; likely solid color / brightness / on-off first, then effects).

### What we explicitly avoid (safety)

| Approach | Verdict |
|----------|---------|
| **User-mode HID** (Feature/Output reports via Windows HID APIs or hidapi) | **Preferred** — same class of approach as OpenRGB-style tools |
| **Windows kernel / filter driver** | **Out of scope** — signing burden, BSOD risk, harder to reverse |
| **MCU ISP / firmware flash** | **Out of scope for v1** — brick risk (tools like Sinowealth ISP utilities exist in the wild; we are not going there for “safe & reversible”) |

### Safety / reversibility model

- Uninstall the app → keyboard still works (stock HID)  
- Prefer **FN + ESC** as hardware reset if lighting gets weird  
- Never replace the Microsoft keyboard driver  
- Never flash firmware for “just RGB”  
- Probe vendor collections carefully; avoid blind high-risk report spam  

### Difficulty (honest)

| Phase | Difficulty |
|-------|------------|
| Enumerate HID, list report IDs | Easy |
| Capture / decode protocol | Medium–hard |
| Simple RGB app once packets known | Medium |
| Per-key / OpenRGB-quality effects | Harder |

OpenRGB has Sinowealth-related controllers under other VIDs (e.g. `0x258A`); **`0x3402:0x0303` is not a known free lunch**. Some historical Sinowealth *keyboard* detectors were even disabled in OpenRGB over VID/PID reuse / bricking concerns on Redragon-family boards — treat relatives carefully.

---

## Platform choice (Windows vs Linux)

| | **Windows** | **Fedora / Linux** |
|--|-------------|---------------------|
| Daily use of the app | Main OS for this machine | Secondary unless dual-boot is primary |
| USB capture | **Wireshark + USBPcap** already installed | Excellent `usbmon` |
| HID access | Works; sometimes finicky on which collection / elevation | Often cleaner (`hidraw`, udev) |
| RE tools already here | Ghidra, x64dbg, WinDbg/`usbview`, Python, Java | Would need reinstall / dual maintain |
| Safety | Same if user-mode only | Same |

**Decision so far:** default workspace is **Windows**. Reboot to Fedora only if USB capture or HID open access becomes a real blocker. WSL is a poor primary path for raw physical USB HID without extra setup.

---

## Tools already available on this PC (inventory)

Useful for this project when we start hands-on RE:

| Tool | Status | Notes |
|------|--------|--------|
| **Ghidra 12.0.4** | Installed | `C:\Tools\Ghidra\ghidra_12.0.4_PUBLIC\` |
| **Java 21** | Installed | Required for Ghidra |
| **Wireshark 4.6.x** | Installed | + `tshark` / `dumpcap` |
| **USBPcap 1.5.4** | Installed | USB capture for Wireshark |
| **Npcap** | Installed / running | Capture backend |
| **x64dbg** | Installed | `C:\Tools\x64dbg` (WinGet) |
| **WinDbg / WDK debuggers** | Installed | Includes `usbview.exe` |
| **Python 3.14** | Installed | HID libs **not** installed yet |
| **winget / choco / pip / cargo** | Available | Easy to add small tools |

**Not installed yet (likely next when coding starts):** `hidapi` / Python `hid`, `hidapitester`, optionally Frida if we ever hook a vendor app.

---

## Recommended technical approach (not implemented yet)

1. **Smoke test** — check whether OpenRGB / SignalRGB already claim `3402:0303` (unlikely).  
2. **Enumerate** — list HID paths, usage pages, report IDs for vendor collections only.  
3. **Capture** — Wireshark + USBPcap while changing lighting via FN (and any vendor software if found).  
4. **Decode** — map packets to color / mode / brightness.  
5. **Replay** — small user-mode script/app; prove solid color + brightness.  
6. **UI** — simple desktop app; optional later OpenRGB contribution if protocol is clean.

Possible future shapes:

- **A (recommended):** Custom user-mode RGB app  
- **B:** OpenRGB controller / PR  
- **C:** Try existing RGB hubs first, then A  

### v1 success options (undecided)

1. Solid color + brightness + on/off *(likely best first milestone)*  
2. Preset effects matching FN modes  
3. Per-key / advanced effects (+ OpenRGB later)  

---

## Repo layout

```text
.
├── README.md                 # This document
├── LICENSE                   # MIT
├── .gitignore
├── docs/
│   ├── assets/               # Photos of manual + back label
│   └── notes/                # Extra research notes (as needed)
└── (src later)               # Control app / tools — not started
```

Photos of the physical unit and manuals live under `docs/assets/` for reference.

---

## Non-goals (for now)

- Shipping a signed kernel driver  
- Reflashing or “QMK replacement” firmware  
- Guaranteeing OpenRGB support without RE  
- Controlling the separate `18F8:0FC0` mouse  

---

## References & breadcrumbs

- USB IDs observed on host: `3402:0303` (keyboard), `18F8:0FC0` (gaming mouse)  
- Model: **ET-7449** (back label)  
- Manufacturer context: Eastern Times Technology Co., Ltd; Redragon collab / rebrand ecosystem  
- Compliance example listing models `K737B-RGB-PRO`, `ET-7449` (verify applicability per variant)  
- OpenRGB Sinowealth history: useful related art, **not** a drop-in for this VID/PID  

---

## License

MIT — see [LICENSE](LICENSE).

---

## Disclaimer

This project is for **personal interoperability and learning** with hardware you own. Reverse engineering and HID experimentation carry risk. Prefer user-mode access, keep factory reset (FN+ESC) in mind, and do not flash firmware unless you accept permanent device loss. No warranty — if it breaks, you get to keep both pieces.
