# Probe B (`cmd01`) — results

**Time:** 2026-07-19 15:05 PDT  
**Packet:** `05 01 00 00 00 00`  
**Pcap:** `captures/set-probe-20260719-150558.pcapng`

## SET

| | |
|--|--|
| ioctl | **OK** |
| Wire | SET_REPORT Feature id=5 · 6 B · `05 01 00 00 00 00` · iface 1 |

## GET 0x06 after

```text
05 01 00 00 00 00 06 00 38 02 95 01 81 06 …
```

Compared to post–Probe A (`05 00 00 00 00 00 06 00 38 02…`):

| Offset | After A | After B |
|--------|---------|---------|
| 0 | 05 | 05 |
| **1** | **00** | **01** |
| 2–5 | 00 | 00 |
| 6–13 | 06 00 38 02 95 01 81 06 | **same** |

**Confirmed:** GET Feature 0x06 **echoes the last SET Feature 0x05 payload in bytes 0–5**.  
Bytes 6–13 look like a **stable suffix** (not changed by this cmd).

Light effect: user reports **possible faster animation** (uncertain — not a hard color/mode flip).  
Next baseline: user will FN-switch to another color so further probes are easier to judge.

## Meaning for RE

- 0x05 SET is a live command register the host can write.
- 0x06 GET is (at least partially) a **status/echo page**, not an empty no-op.
- RGB still needs a **command + args** combination (or 0x06 SET blob) that the firmware treats as lighting — pure `cmd=1` with zero args may be no-op for lights.
