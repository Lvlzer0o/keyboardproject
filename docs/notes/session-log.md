# Session log

High-level timeline of discovery work. Details live in the root [README](../../README.md).

## 2026-07-19

- Empty project folder; idea floated for a challenging keyboard-related project.
- Identified connected keyboard via Windows PnP/WMI:
  - Primary: `VID_3402` / `PID_0303`
  - Bus-reported name: **American Future BY iBUYPOWER MK9 Mechanical Keyboard**
  - Secondary HID keyboard interface from gaming mouse `VID_18F8` / `PID_0FC0`
- Manual photo catalogued FN lighting and media shortcuts (16 backlight modes, factory reset FN+ESC, etc.).
- Discussed RGB software idea with hard constraints: **safe, reversible, no breakage** → prefer user-mode HID, avoid kernel drivers and firmware flash.
- Inventoried RE tools: Ghidra 12, Wireshark + USBPcap, x64dbg, WinDbg/usbview, Python 3.14, Java 21. Missing: hidapi / Frida.
- Platform advice: default to **Windows**; Fedora only if capture/HID access blocks progress.
- Back-of-keyboard photo: model **ET-7449**, iBUYPOWER MK9 RGB, Made in China.
- Research: ET-7449 appears in Eastern Times / Redragon compliance context; iBUYPOWER publicly collabed with Redragon on MK9 line.
- Initialized git repo, README, LICENSE, .gitignore, asset docs; published to GitHub.
- User rebooting into **Fedora**; added root **CONTINUE.md** handoff for cross-OS resume (clone/pull repo, read CONTINUE first).

## 2026-07-19 (Fedora)

- Cloned repo to `~/Dev/keyboardproject` on Fedora.
- Public-web protocol search: **no** published RGB/HID protocol for `3402:0303` / ET-7449; OEM Eastern Times / Redragon family only; OpenRGB Sinowealth is related art (`0x258A`), keyboard detectors often disabled.
- Full **read-only** hardware sweep (no device writes). Artifacts:
  - Summary: `docs/notes/fedora-readonly-sweep.md`
  - Raw dump: `docs/notes/fedora-readonly-sweep-20260719-143524/`
- Confirmed live: `3402:0303` BY Tech MK9; IF0 boot kb `hidraw4`; IF1 vendor multi `hidraw5` + `hiddev3`.
- Decoded IF1 feature reports: **0x05 (5+1 B)** and **0x06 (519+1 B)** on vendor page `0xFF00` — primary RGB RE targets.
- OpenRGB list: DRAM only; **keyboard not supported/detected**.
- Blocked without sudo/udev: GET_FEATURE, usbhid-dump, easy usbmon group access.
- User installed `hidapi-devel`, `libusb1-devel`, `pip install --user hid`; added to `usbmon` group (needs re-login).
- Elevated dump: `usbhid-dump` OK (matches sysfs rdesc). GET_FEATURE all EPIPE — **queried wrong hidraw** (boot IF0); hidraw numbers **swap** across re-enumeration. IF1 is currently `hidraw4` (240 B). Robust script: `docs/notes/elevated-dump/get-feature-if1.sh`.
- Correct IF1 GET: **0x05 EPIPE**; **0x06 OK all-zero** at lens 520/65/9/8. Analysis: `elevated-dump/analysis-get-feature-if1.md`. Next: usbmon + FN capture.
- User rebooting; **CONTINUE.md** rewritten as full post-reboot handoff.

## 2026-07-19 (Fedora, post-reboot)

- Confirmed `usbmon` group + readable `/dev/usbmon*`; keyboard still `3402:0303` on bus 3 dev 8.
- hidraw map after reboot: IF0=`hidraw4`, IF1=`hidraw5` (swapped again).
- **50 s dumpcap** on `usbmon3` → `captures/fn-lighting-20260719-145150.pcapng` (6960 pkts, 0 drops).
- Analysis (`docs/notes/fn-usbmon-capture-20260719.md`): **no control transfers to keyboard**; only empty interrupt reports on EP 0x81/0x82. **FN lighting is MCU-local.**
- User confirmed: colors / FN lighting **worked normally** during that period (not a missed-key false negative).
- Product-page note: some MK9 Pro listings mention HYTE Nexus (SKU may differ) — possible future Windows capture target; no public protocol for this PID.
- Installed IF1 udev rule; ran **GET before/after FN color change** (`post-fn-get-20260719-145726/`).
  - **0x06 still all-zero and identical** before/after; **0x05 still EPIPE**.
  - Conclusion: GET does not mirror FN lighting state. Passive FN+GET RE exhausted.
  - udev reinstall: IF1 got ACL `user:gigachad:rw-` → **user RDWR works**; IF0 stays locked. Rule fixed to use `ENV{ID_USB_INTERFACE_NUM}` (cannot combine ATTRS from device + interface parents).
- OpenRGB GUI SEGV on Fedora during I2C DIMM detect (null log string) — unrelated to MK9; CLI still lists DRAM only.
- Scaffolded Fedora SET path:
  - `tools/set_feature_if1.py` — IF1-only, dry-run default, `--apply --i-understand-risk`
  - `tools/capture_set_probe.sh` — usbmon wrapper
  - `docs/notes/set-hypothesis-01.md` — Probe A `zero6` first
- **Probe A** (`zero6`): SET OK; **no light change**; typing OK. GET 0x06 began returning data.
- **Probe B** (`cmd01` `05 01 00 00 00 00`): SET OK. GET 0x06 **echoes last 0x05 SET in bytes 0–5**; bytes 6–13 stable suffix.
- User: possible **faster lighting animation** after B (soft observation); FN solid **full red** as baseline.
- GET after FN red still echoed last host SET (`05 01…`) — **GET does not mirror FN color**.
- **Probe C** `cmd02`: no light change on solid red.
- **Probe D** `05 03 00 ff 00 00`: SET OK + echo; **no light change** (still solid red). User questioned whether SETs ran — confirmed on wire + GET echo.
- User-driven FN button capture (`fn-user-buttons-20260719-150957`): still **0 control** URBs; interrupt vendor **`03 08 00 01`** and **`06 0a 07 00…`** every press — **fixed**, not color/mode encoding.
- **Custom mode (FN+Backspace) color cycle confirmed** (per key, press to advance):
  red → green → yellow → blue → purple → turquoise → white → **off** → (repeat).
  **Save:** FN+Backspace again. Multi-slot/memory unknown.
  Documented in `docs/notes/custom-mode-fn-backspace.md`.
