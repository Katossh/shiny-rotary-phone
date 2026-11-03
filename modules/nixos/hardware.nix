{ pkgs, ... }:

{
  # AMD Ryzen 7000 platform and its integrated RDNA2 graphics.
  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;

    graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Load amdgpu early for a clean Wayland/KMS hand-off.
    amdgpu.initrd.enable = true;

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

    # Monthly checksum scrub of the single Btrfs filesystem. All configured
    # subvolumes live on the same filesystem, so scrubbing / avoids duplicate work.
    btrfs.autoScrub = {
      enable = true;
      fileSystems = [ "/" ];
      interval = "monthly";
    };

    # Grant the active local desktop user access to these HID interfaces.
    # Required for browser-based device configuration (e.g. ATK Hub WebHID).
    udev.extraRules = ''
      # VXE R1 Pro receiver.
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="373b", ATTRS{idProduct}=="1272", TAG+="uaccess"

      # VXE NordicMouse 1K receiver.
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f58a", TAG+="uaccess"

      # LEKU NUT65 keyboard.
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="342d", ATTRS{idProduct}=="e51a", TAG+="uaccess"
    '';

    # Used by Noctalia's network, Bluetooth, battery, and power UI.
    upower.enable = true;
    power-profiles-daemon.enable = true;
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
}
