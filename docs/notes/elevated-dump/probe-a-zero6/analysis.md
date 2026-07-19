# Probe A (`zero6`) — results

**Time:** 2026-07-19 15:04 PDT  
**Packet:** `05 00 00 00 00 00`  
**Tool:** `tools/set_feature_if1.py --preset zero6 --apply --i-understand-risk`  
**Pcap:** `captures/set-probe-20260719-150402.pcapng`

## SET on the wire

| Field | Value |
|-------|--------|
| ioctl | **OK** (~0.8 ms) |
| USB | CONTROL OUT · device 8 · interface **1** |
| bmRequestType | `0x21` (Class, Host→Device, Interface) |
| bRequest | `9` (SET_REPORT) |
| wValue | `0x0305` (Feature, report ID **5**) |
| wIndex | `1` (IF1) |
| wLength | `6` |
| Data | `05 00 00 00 00 00` |

**Conclusion:** Host→device Feature SET on report **0x05** is accepted by the firmware path (no stall).

## GET after SET

| Report | Result |
|--------|--------|
| 0x05 len 6 | Still **EPIPE** |
| 0x06 len 520 | **OK**, stable, **8 nonzero bytes** (was all-zero pre-probe) |

Stable payload (two consecutive GETs identical):

```text
offset 0..5:  05 00 00 00 00 00   ← matches last SET payload
offset 6..13: 06 00 38 02 95 01 81 06
offset 14..:  zeros
```

### Interpretation (tentative)

1. **Strong:** SET 0x05 works; control path is live.  
2. **Interesting:** GET 0x06 content **changed** after the SET and appears to **echo the last 0x05 SET** in the first 6 bytes.  
3. **Unclear:** bytes @6..13 — not yet mapped; do not assume RGB table. Could be firmware status, could be unrelated.  
4. **Still true:** GET 0x05 remains unusable (EPIPE).

Light effect of all-zero SET: **no change** (user confirmed). Typing normal.

## Next

- Probe B one cmd-byte (`cmd01`, etc.) under capture; watch whether GET 0x06[0:6] echoes the new packet and whether lights change.  
