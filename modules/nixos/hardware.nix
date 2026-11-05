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

  services = {
    # Firmware updates are offered only for devices supported by LVFS/fwupd.
    fwupd.enable = true;

    # Monitor available SMART-capable storage devices. Alerts go to the journal
    # and wall by the NixOS smartd defaults.
    smartd = {
      enable = true;
      autodetect = true;
    };

    # Used by Noctalia's network, Bluetooth, battery, and power UI.
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };

  # Hardware diagnostics for the CPU, NVMe storage, buses, and graphics stack.
  environment.systemPackages = with pkgs; [
    lm_sensors
    nvme-cli
    pciutils
    smartmontools
    usbutils
    vulkan-tools
  ];
}
