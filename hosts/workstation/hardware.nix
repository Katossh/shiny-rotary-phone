{
  config,
  inputs,
  pkgs,
  ...
}:

let
  # Use CachyOS BORE + Clang ThinLTO for Zen 4. The pinned kernel builder
  # normally disables BTF for LTO while its pahole is older than 1.33.
  # sched_ext needs BTF, so retain BTF and disable optional Rust kernel
  # components: Linux Kconfig does not support Rust + BTF + LTO together.
  cachyosKernel =
    (pkgs.cachyosKernels."linuxPackages-cachyos-bore-lto-zen4".kernel.override {
      structuredExtraConfig = with pkgs.lib.kernel; {
        DEBUG_INFO_BTF = yes;
        RUST = no;
      };
    }).overrideAttrs (_: {
      # Build this kernel from the pinned sources on this machine rather than
      # silently substituting the third-party binary-cache build.
      allowSubstitutes = false;
      preferLocalBuild = true;
    });
in
{
  imports = [
    # AMD Ryzen 7000 Raphael iGPU, common AMDGPU support, and AMD P-State.
    inputs.nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
  ];

  # Preserve CachyOS's package set and rebuild its module set around the
  # locally compiled BORE + ThinLTO + Zen 4 kernel.
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.linuxPackagesFor cachyosKernel;

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
