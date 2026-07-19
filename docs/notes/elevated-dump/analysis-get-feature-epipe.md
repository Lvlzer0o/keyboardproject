# GET_FEATURE EPIPE analysis (2026-07-19)

## What you ran successfully
- `hidapi-devel`, `libusb1-devel`, `pip install --user hid` OK
- `usbmon` group added (log out/in still needed for capture)
- `usbhid-dump` OK — descriptors match our earlier sysfs decode exactly
- GET_FEATURE all returned **errno 32 EPIPE** (USB STALL / broken pipe)

## Root cause of the failed GETs (important)

**hidraw node numbers are not stable.** After re-enumeration they swapped:

| Now (live) | Interface | rdesc size | Role |
|------------|-----------|------------|------|
| **/dev/hidraw4** | **IF 1** | **240 B** | **Vendor multi — RGB target** |
| **/dev/hidraw5** | **IF 0** | **67 B** | Boot keyboard (typing) |

Earlier sweep had the opposite assignment (hidraw4=boot, hidraw5=vendor).

The elevated script queried **`/dev/hidraw5`**, which is currently the **boot keyboard**. Boot HID has **no Feature reports** → kernel/device returns **EPIPE**. That failure is expected and **not** proof that Feature 0x05/0x06 are dead.

The “hidraw4 sanity” probe used report ID 0 on the boot interface — also expected to fail.

## usbhid-dump confirmation
- `003:008:000` = IF0 boot, 67-byte rdesc (standard keyboard)
- `003:008:001` = IF1 multi, 240-byte rdesc including Feature **0x05** (5 B) and **0x06** (519 B)

## Next step
Re-run GET_FEATURE against **whichever hidraw is IF1** (not a hard-coded number), via udev `ID_USB_INTERFACE_NUM=01`.

