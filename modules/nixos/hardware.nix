{ ... }:

{
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Used by Noctalia's network, Bluetooth, battery, and power UI.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
}
