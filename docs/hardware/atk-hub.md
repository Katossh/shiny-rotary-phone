# ATK Hub on Chromium

Starforge grants the active local desktop user access to ATK/VXE HID raw devices
from USB vendor ID 373b through udev's uaccess tag. Chromium's WebHID
implementation needs access to the corresponding /dev/hidraw* device.

This avoids making the device world-writable. The permission is limited to the
active local seat user.

## After applying the configuration

1. Rebuild and switch to the updated NixOS generation.
2. Unplug and reconnect the mouse receiver so udev reapplies its permissions.
3. Open the ATK Hub site in Chromium and explicitly connect to the receiver when
   Chromium presents the device chooser.
4. Check chrome://device-log for HID connection and permission errors.

The udev rule removes a common Linux device-permission blocker. It cannot
override a mouse's firmware-reported sleep state or fix a bug in ATK Hub's
battery/sleep telemetry. If the mouse is still reported as asleep, record the
receiver's USB VID:PID with lsusb -nn and inspect the Chromium device log
before broadening the rule further.
