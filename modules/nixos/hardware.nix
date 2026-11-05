{ pkgs, ... }:

{
  # Common workstation capabilities. CPU/GPU platform modules and
  # device-specific udev rules live in hosts/workstation/hardware.nix.
  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Firmware updates are offered only for devices supported by LVFS/fwupd.
  services.fwupd.enable = true;

  # Hardware diagnostics for the CPU, buses, and graphics stack.
  environment.systemPackages = with pkgs; [
    lm_sensors
    pciutils
    usbutils
    vulkan-tools
  ];
}
