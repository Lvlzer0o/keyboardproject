# FN + Backspace — custom key LED mode (discovered)

**Source:** Hands-on on iBUYPOWER MK9 / ET-7449 / `3402:0303` (2026-07-19).  
**Official docs:** only say “Customize key LED mode” — no color list or save steps.

---

## Enter / leave / save

| Action | Shortcut | Notes |
|--------|----------|--------|
| Enter custom mode | **FN + Backspace** | Board enters per-key paint mode |
| **Save + leave** | **FN + Backspace** again | User-confirmed: second press **saves** the custom map and exits |
| Hard reset all lighting | **FN + ESC** (~3s on sticker) | Factory lighting defaults |

### Memory / slots (unknown)

| Question | Status |
|----------|--------|
| Does save persist across unplug/reboot? | **Likely yes** (typical for this class) — not formally re-tested in notes |
| Multiple save slots (e.g. FN+1…5)? | **Unknown** — no confirmed multi-slot workflow yet |
| How much NVM / does FN+ESC wipe customs? | **Unknown** — treat FN+ESC as full lighting factory reset |

Custom painting is **on-device only**. USB capture while in custom mode did not expose a host-side color map (GET 0x06 still only echoed last software SET).

---

## Per-key color cycle (confirmed)

While in custom mode, **pressing a given key** advances **that key’s** LED through this fixed order (repeat wraps):

| Step | Color |
|-----:|--------|
| 1 | **Red** |
| 2 | **Green** |
| 3 | **Yellow** |
| 4 | **Blue** |
| 5 | **Purple** |
| 6 | **Turquoise** (cyan) |
| 7 | **White** |
| 8 | **Off** |
| → | back to red… |

So this is **not** free RGB (no arbitrary R/G/B). It is an **8-state palette** per key:

```text
R → G → Y → B → Purple → Turquoise → White → Off → (repeat)
```

### How to “design”

1. **FN + Backspace** → custom mode.  
2. Tap each key until it shows the color you want (or off).  
3. Build the layout key-by-key.  
4. **FN + Backspace** again → **save and exit**.  
5. If lost: **FN + ESC**.

### Relation to global FN lighting

| Global (outside custom) | Custom mode |
|-------------------------|-------------|
| FN+Alt = 16 **effects** | Per-key **static palette** states |
| FN+Ctrl = whole-board color | Per-key cycle above |
| Animations / speed / brightness | Key paint is discrete steps |

“Full red” from FN+Ctrl is a **global** mode. Custom mode is a **separate** per-key map with only those 8 states.

---

## Implications for software RE

- Host “true RGB” may still exist on Feature 0x05/0x06, but **stock custom UI is 8-color indexed**, not 24-bit.  
- A v1 app that only needs to match stock custom mode could target **palette index 0–7 per key** if we ever find the SET layout.  
- Yellow ≈ R+G, purple ≈ R+B, turquoise ≈ G+B, white ≈ R+G+B — classic cheap RGB mix, still discrete steps on the FN UI.

---

## Still unknown

- [x] **Save / exit** — FN + Backspace again  
- [ ] Multiple slots (FN+1…5 or similar)?  
- [ ] Persistence across power cycle (spot-check)  
- [ ] Whether FN+ESC clears saved custom map  
- [ ] USB packets when a key’s palette index changes  

---

## Changelog

| Date | Note |
|------|------|
| 2026-07-19 | User confirmed 8-step cycle: red, green, yellow, blue, purple, turquoise, white, off |
| 2026-07-19 | User: FN+Backspace again **saves**; multi-slot / memory details unknown |
