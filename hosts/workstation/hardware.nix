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

  # Track the newest maintained stable kernel exposed by the locked Nixpkgs.
  # Keep this host-specific rather than changing the reusable boot module.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.cpu.amd.updateMicrocode = true;
  hardware.amdgpu.initrd.enable = true;

  # This workstation has an AK620 Digital; its display daemon runs in the
  # configured user's Home Manager session, not as a system-wide service.
  home-manager.users.${config.starforge.user.username}.starforge.user.hardware.deepcoolDigital.enable =
    true;

  # Seat-scoped uaccess rules must run before systemd's 73-seat-late.rules.
  # services.udev.extraRules writes 99-local.rules, which is too late.
  # The AK620 daemon instead uses a fixed owner because it is a persistent
  # user service and should not depend on the timing of logind seat ACLs.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "workstation-hidraw-rules";
      destination = "/etc/udev/rules.d/70-workstation-hidraw.rules";
      text = ''
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="373b", TAG+="uaccess"

        # DeepCool AK620 Digital / Digital SE display (shared USB VID 3633, PID 0002).
        # The daemon runs as the configured workstation user; keep access private to that account.
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", ATTRS{idProduct}=="0002", OWNER="${config.starforge.user.username}", MODE="0600"

        # VXE NordicMouse 1K receiver.
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f58a", TAG+="uaccess"

        # LEKU NUT65 keyboard.
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="342d", ATTRS{idProduct}=="e51a", TAG+="uaccess"
      '';
    })
  ];

  environment.systemPackages = with pkgs; [
    amdgpu_top
    libva-utils
  ];
}
