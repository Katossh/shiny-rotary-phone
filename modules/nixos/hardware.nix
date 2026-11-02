{ pkgs, ... }:

{
  # AMD Ryzen 7000 platform and its integrated RDNA2 graphics.
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load amdgpu early for a clean Wayland/KMS hand-off.
  hardware.amdgpu.initrd.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Firmware updates are offered only for devices supported by LVFS/fwupd.
  services.fwupd.enable = true;

  # Monitor available SMART-capable storage devices. Alerts go to the journal
  # and wall by the NixOS smartd defaults.
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # Monthly checksum scrub of the single Btrfs filesystem. All configured
  # subvolumes live on the same filesystem, so scrubbing / avoids duplicate work.
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
    interval = "monthly";
  };

  # Hardware diagnostics for the CPU, NVMe storage, buses, and graphics stack.
  environment.systemPackages = with pkgs; [
    amdgpu_top
    libva-utils
    lm_sensors
    nvme-cli
    pciutils
    smartmontools
    usbutils
    vulkan-tools
  ];

  # Used by Noctalia's network, Bluetooth, battery, and power UI.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
}
