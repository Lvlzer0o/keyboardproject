# GET_FEATURE before/after FN lighting change — 2026-07-19

**Run dir:** `docs/notes/elevated-dump/post-fn-get-20260719-145726/`  
**udev:** `/etc/udev/rules.d/99-mk9-if1-hidraw.rules` installed. After reinstall/trigger, IF1 has `uaccess` ACL (`user:gigachad:rw-`) → **user RDWR open works**; IF0 stays `600` root. Note: rule must not mix `ATTRS` from two parents — use `ENV{ID_USB_INTERFACE_NUM}` (see udev file comments).

---

## Results

| Report | Before FN change | After FN change |
|--------|------------------|-----------------|
| **0x05** len 6/9 | EPIPE (32) | EPIPE (32) |
| **0x06** len 520/65/9/8 | OK, **all `0x00`** | OK, **all `0x00`** (byte-identical) |
| IF0 any | EPIPE | EPIPE |

Binary compare: every `feature-if1-id06-len*.bin` is **SAME** before vs after; nonzero count = **0**.

User confirmed FN colors/controls work normally; capture earlier showed no host RGB traffic for FN.

---

## Conclusions

1. **GET Feature 0x06 does not mirror on-device lighting state** changed via FN. Idle or “pretty lights,” host still reads zeros (including no report-ID echo in byte 0).
2. **0x05 remains not GETtable** — still consistent with SET-only command report (or unused GET path).
3. Combined with usbmon FN capture: stock lighting is **MCU-local**, and the **Feature GET channel is not a live status mirror**. Host software, if any, almost certainly uses **SET** (write) — possibly write-then-read — not passive GET of FN state.
4. Passive RE of this board is exhausted for FN + GET. Next real signal needs either:
   - a **companion app** that issues SETs (best), or
   - **hypothesis-driven SET** under usbmon with FN+ESC undo.

---

## udev note

After rule install, IF1 is `crw-rw---- root:root` (group rw, but group is root). User open still EACCES.  
Fix draft: match `ATTRS{bInterfaceNumber}=="01"` and set `GROUP="wheel"` (user is in wheel) + `TAG+="uaccess"`. Re-apply and trigger/replug.
