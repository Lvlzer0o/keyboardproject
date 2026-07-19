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
