# Probe C — solid-red baseline + `cmd02`

## Baseline (FN full red, no SET)

GET 0x06 still:

```text
05 01 00 00 00 00 06 00 38 02 95 01 81 06 …
```

Same as post–`cmd01`. **FN solid red does not appear in GET 0x06** — reinforces: this page echoes host Feature SETs, not MCU/FN lighting state.

## Probe C packet

```text
05 02 00 00 00 00
```

| | |
|--|--|
| SET | OK |
| GET after | `05 02 00 00 00 00 06 00 38 02 95 01 81 06 …` |
| Pcap | `captures/set-probe-20260719-150755.pcapng` |

Light effect on solid red: *user to confirm*.
