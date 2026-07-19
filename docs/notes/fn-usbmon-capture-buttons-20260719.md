# FN button capture (user-driven) — 2026-07-19 15:09

**Pcap:** `captures/fn-user-buttons-20260719-150957.pcapng` (~45 s, 718 frames)  
**Why:** User asked to watch button presses instead of guessing SET packets.

## Headline

| Question | Result |
|----------|--------|
| Any **control** / Feature SET from FN? | **None** (0 control URBs to device 8) |
| Any interrupt activity? | **Yes** — richer than the first FN capture |
| Does payload change with color/mode? | **No** — same bytes every press in this window |

## Interrupt payloads seen (device 8)

| Count | EP | Payload | Report |
|------:|----|---------|--------|
| 45 | 0x81 | `00…00` (8 B) | boot empty |
| 44 | 0x82 | `02 00 00` | consumer empty |
| 44 | 0x82 | `01 00` | system empty |
| 44 | 0x82 | `03 08 00 01` | **vendor IN 0x03** |
| 44 | 0x82 | `04` + zeros | key bitmap empty |
| 29 | 0x82 | `06 0a 07 00 00 00 00 00` | **vendor IN 0x06** (7 data bytes) |

Every FN lighting action in this capture produced the **same** `03 08 00 01` and (usually) the **same** `06 0a 07 00 00 00 00 00`. No per-color / per-mode encoding on the wire.

## Why this doesn’t replace SET guessing

1. Lights still change **on the MCU**; host only gets a **fixed event nibble**.  
2. Host RGB control still needs **Feature SET** (0x05/0x06 OUT) — the opposite direction.  
3. These IN reports are still useful: prove vendor page is alive; possible “notify host” or macro channel — **not** a lighting state dump.

## Vs first FN capture

Earlier capture only saw empty 0x01/0x02/0x04. This one also hits **0x03** and **0x06 Input** — likely more / different FN keys pressed, or firmware always emits them when FN combos fire.
