{
  config,
  inputs,
  lib,
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

  # Build the newest maintained kernel with Clang/LLD. Keep the kernel
  # version and its matching module set aligned.
  boot.kernelPackages = pkgs.linuxPackagesFor (
    pkgs.linuxPackages_latest.kernel.override {
      stdenv = pkgs.llvmPackages.stdenv;
      # Nixpkgs passes HOSTCC/HOSTCXX/HOSTAR/HOSTLD explicitly, so LLVM=1
      # alone does not select LLVM for the host-side kernel build tools.
      extraMakeFlags = [
        "LLVM=1"
        "HOSTCC=${pkgs.llvmPackages.stdenv.cc}/bin/clang"
        "HOSTCXX=${pkgs.llvmPackages.stdenv.cc}/bin/clang++"
        "HOSTAR=${pkgs.llvmPackages.llvm}/bin/llvm-ar"
        # LLVM=1 adds -fuse-ld=lld; give Clang the exact LLD executable.
        # Kernel host tools need libelf and libcrypto at runtime inside the sandbox.
        "HOSTLDFLAGS=--ld-path=${pkgs.llvmPackages.lld}/bin/ld.lld -Wl,-rpath,${
          lib.makeLibraryPath [
            pkgs.elfutils
            pkgs.openssl
          ]
        }"
        "HOSTLD=${pkgs.llvmPackages.lld}/bin/ld.lld"
      ];
    }
  );

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
