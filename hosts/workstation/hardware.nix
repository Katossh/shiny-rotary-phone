{
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    # AMD Ryzen 7000 Raphael iGPU, common AMDGPU support, and AMD P-State.
    inputs.nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
  ];

  # Use the upstream prebuilt non-LTO CachyOS kernel for Zen 4. Its release
  # configuration already enables BTF, BPF, and sched_ext; do not override it,
  # so the kernel derivation continues to match the published binary cache.
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-latest-zen4";

  # Enable the kernel NT synchronization primitive used by Wine/Proton.
  boot.kernelModules = [ "ntsync" ];

  # Let the NVMe controller manage its own I/O scheduling. Grant the
  # NTSync device exclusively to the configured workstation user: the uaccess
  # tag was applied, but logind did not create the required session ACL.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
    KERNEL=="ntsync", OWNER="${config.starforge.user.username}", MODE="0600"
  '';

  hardware.cpu.amd.updateMicrocode = true;
  hardware.amdgpu.initrd.enable = true;

  # This workstation has an AK620 Digital; its display daemon runs in the
  # configured user's Home Manager session, not as a system-wide service.
  home-manager.users.${config.starforge.user.username}.starforge.user.hardware.deepcoolDigital.enable =
    true;

  # Give the configured account direct access to only the HID interfaces
  # used by this workstation's device configurators and DeepCool daemon.
  # Fixed ownership avoids relying on logind's dynamic uaccess ACL timing.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "workstation-hidraw-rules";
      destination = "/etc/udev/rules.d/70-workstation-hidraw.rules";
      text = ''
        # ATK Hub WebHID interfaces (ATK vendor ID; covers its receiver variants).
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="373b", OWNER="${config.starforge.user.username}", MODE="0600"

        # DeepCool AK620 Digital / Digital SE display (shared USB VID 3633, PID 0002).
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", ATTRS{idProduct}=="0002", OWNER="${config.starforge.user.username}", MODE="0600"

        # VXE NordicMouse 1K receiver.
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f58a", OWNER="${config.starforge.user.username}", MODE="0600"

        # LEKU NUT65 keyboard (VIA WebHID).
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="342d", ATTRS{idProduct}=="e51a", OWNER="${config.starforge.user.username}", MODE="0600"
      '';
    })
  ];

  environment.systemPackages = with pkgs; [
    amdgpu_top
    libva-utils
  ];
}
