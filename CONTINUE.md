# CONTINUE HERE (cross-OS handoff)

**Read this first** when picking the project back up on Fedora (or any new session).

Last updated: **2026-07-19** (Windows session, before reboot to Fedora)

---

## One-line status

Research + GitHub scaffold done for **iBUYPOWER MK9 RGB** control. **No code/protocol work yet.** Next: safe HID discovery / capture on Linux if useful, still **user-mode only**.

---

## Repo

| | |
|--|--|
| **GitHub** | https://github.com/Lvlzer0o/keyboardproject |
| **Clone** | `git clone https://github.com/Lvlzer0o/keyboardproject.git` |
| **Branch** | `main` |
| **Account** | `Lvlzer0o` |

On Fedora, if this folder isn’t already the clone, clone fresh and open that directory.

Primary docs:

1. **This file** — where we left off / what to do next  
2. **[README.md](README.md)** — full research dump  
3. **[docs/notes/session-log.md](docs/notes/session-log.md)** — short timeline  

Reference photos:

- `docs/assets/manual-shortcuts.png` — FN shortcut table from the manual  
- `docs/assets/keyboard-back-label.png` — back sticker (model **ET-7449**)

---

## Device facts (do not re-discover from scratch)

| Field | Value |
|--------|--------|
| Product | iBUYPOWER **MK9** RGB Mechanical Keyboard (“American Future BY iBUYPOWER MK9…”) |
| Model (sticker) | **ET-7449** |
| USB | **`3402:0303`** (rev `2002` seen on Windows) |
| OEM context | Eastern Times / **Redragon** collab ecosystem (MK9 line); ET-7449 also appears on certs with Redragon K737B-RGB-PRO naming — treat as family, not guaranteed identical PCB |
| Other HID on same PC (Windows) | Gaming mouse **`18f8:0fc0`** (not the keyboard) |

Lighting is controlled on-device with **FN** (16 modes, color, brightness, speed, on/off). **FN+ESC = factory reset** (hardware undo).

Windows saw multiple HID collections including **vendor-defined** ones on the composite device — those are the likely RGB target.

---

## Project intent (constraints)

User wants software to **change RGB** that is:

- **Safe**
- **Reversible**
- **Doesn’t break typing / the system**

Agreed approach:

| Do | Don’t |
|----|--------|
| User-mode HID (hidraw / hidapi / Feature reports) | Kernel filter driver “for RGB” |
| Capture + decode protocol carefully | Blind firmware flash / ISP |
| Prefer vendor-defined interface, not boot keyboard | Replace stock keyboard driver |
| Uninstall app → keyboard still works | Assume OpenRGB already supports `3402:0303` (it doesn’t, AFAIK) |

**v1 success** not locked yet; likely best first milestone: solid color + brightness + on/off.

Platform note from Windows session: **Windows is fine as primary**; Fedora is optional for better USB capture (`usbmon`) and cleaner HID access. User is rebooting to Fedora now to work from there.

---

## What is already done

- [x] Identified keyboard (USB + bus string + physical model label)  
- [x] Catalogued FN map from photos  
- [x] Safety / architecture discussion (user-mode RGB app, not a driver)  
- [x] Tool inventory on **Windows** (Ghidra, Wireshark+USBPcap, x64dbg, Python, etc.)  
- [x] README, LICENSE (MIT), `.gitignore`, assets, session log  
- [x] Public GitHub repo created and pushed  

## What is NOT done

- [ ] Confirm device visible on Fedora: `lsusb`, `3402:0303`  
- [ ] Dump HID report descriptor / hidraw nodes  
- [ ] USB capture while changing lights with FN  
- [ ] Decode any RGB packets  
- [ ] Any control script or GUI  
- [ ] OpenRGB / SignalRGB smoke test  

---

## Suggested first commands on Fedora

```bash
# 1. Get the repo
git clone https://github.com/Lvlzer0o/keyboardproject.git
cd keyboardproject
# or: git pull if already cloned

# 2. Is the board here?
lsusb | grep -i 3402
# expect something like: ID 3402:0303 ...

# 3. More detail
lsusb -d 3402:0303 -v

# 4. HID devices (paths vary)
ls -l /dev/hidraw*
# optional: sudo dmesg | tail -50
# optional: sudo cat /sys/kernel/debug/hid/*/rdesc   # if debugfs available
```

Useful packages (install only if missing):

```bash
sudo dnf install -y git wireshark usbutils hidapi hidapi-devel python3-pip \
  libusb1-devel ghidra  # ghidra optional; may be in different package/copr
pip install --user hid  # or hidapi, depending on package
```

Capture idea (when ready — needs permissions / wireshark group):

- Use Wireshark with **usbmon** while toggling FN lighting  
- Save captures **outside** git or under a local `captures/` folder (gitignored)

---

## Safety reminders for the next agent / session

1. Do **not** flash firmware or enter ISP “just to try.”  
2. Do **not** claim exclusive access to the main keyboard interface if it breaks input.  
3. Prefer read/enumerate first; write packets only after a reasoned capture.  
4. **FN+ESC** is the user’s hardware reset for lighting.  
5. Keep commits small; don’t commit huge `.pcap` files (already in `.gitignore`).

---

## Next decision (ask user if unclear)

When implementation starts, confirm v1 scope:

1. Solid color + brightness + on/off (**recommended**)  
2. Preset effects like FN modes  
3. Per-key / advanced (+ maybe OpenRGB later)

---

## Message to the next session

> Continue the **iBUYPOWER MK9 (`3402:0303`, model ET-7449)** RGB project from [CONTINUE.md](CONTINUE.md) + [README.md](README.md). Research and GitHub scaffold are done on Windows; user moved to **Fedora**. Start with `lsusb` / HID enumeration on Linux, stay user-mode and reversible. Do not implement a kernel driver or flash firmware.

---

*Handoff written so work can resume without the previous chat context.*
