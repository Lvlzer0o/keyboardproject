# CONTINUE HERE (session handoff)

**Read this first** after reboot / new chat.

Last updated: **2026-07-19** — Probes A+B SET OK; **GET 0x06 echoes last 0x05 SET**.

---

## One-line status

MK9 host path live: **SET 0x05 OK**; **GET 0x06 echoes last SET in bytes 0–5** (+ stable 8-byte suffix).  
Probe A: no light change. Probe B `cmd01` applied — confirm lights.  
Custom mode: FN+Backspace enter; paint (8-color cycle); **FN+Backspace again = save**. Multi-slot unknown.  
**Next:** smarter SET / 0x06 experiments if continuing RE; never IF0; FN+ESC undo.

---

## Where things live

| What | Path |
|------|------|
| Repo | `~/Dev/keyboardproject` |
| GitHub | https://github.com/Lvlzer0o/keyboardproject |
| FN capture analysis | [docs/notes/fn-usbmon-capture-20260719.md](docs/notes/fn-usbmon-capture-20260719.md) |
| Post-FN GET analysis | [docs/notes/elevated-dump/analysis-post-fn-get.md](docs/notes/elevated-dump/analysis-post-fn-get.md) |
| Post-FN GET artifacts | `docs/notes/elevated-dump/post-fn-get-20260719-145726/` |
| udev rule (fixed draft) | [docs/notes/udev/99-mk9-if1-hidraw.rules](docs/notes/udev/99-mk9-if1-hidraw.rules) |
| GET script | `docs/notes/elevated-dump/get-feature-if1.sh` |
| Timeline | [docs/notes/session-log.md](docs/notes/session-log.md) |

---

## Proven facts

| Fact | Evidence |
|------|----------|
| IF1 is RGB control surface (descriptor) | Feature 0x05 (6 B), 0x06 (520 B) on vendor page |
| FN does not send RGB on USB | usbmon: 0 control to keyboard during FN lighting |
| FN lights work on device | User confirmed |
| GET 0x06 never reflects FN state | before/after identical all-zero |
| GET 0x05 not accepted | EPIPE always |
| OpenRGB unsupported | `--list-devices` DRAM only |

---

## Done

- [x] Device ID + FN map + safety model  
- [x] Fedora HID/USB sweep + rdesc decode  
- [x] Elevated GET on correct IF1  
- [x] usbmon FN capture (MCU-local)  
- [x] GET before/after FN color change (still zeros)  
- [x] udev rule installed (v1; user open still fails — fixed draft pending reinstall)  

## Not done / in progress

- [x] udev IF1: user open OK via `uaccess` ACL (IF0 locked)  
- [x] SET tool + hypothesis 01  
- [x] **Probe A** `zero6` — SET OK on wire  
- [ ] Confirm lights after A; Probe B cmd bytes under capture  
- [ ] User-mode solid color proof  
- [ ] Commit accumulated docs  

---

## Safety

User-mode IF1 only · no firmware · no blind Sinowealth · **FN+ESC** undo · no huge pcaps in git.

---

## Message to next agent

> Passive path closed. Resume from **CONTINUE.md**. Next real work is **host-initiated SET** discovery (app capture preferred, else careful 0x05 experiments under usbmon).
