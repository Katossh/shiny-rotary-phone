{ inputs, pkgs, ... }:

{
  imports = [
    # AMD Ryzen 7000 Raphael iGPU, common AMDGPU support, and AMD P-State.
    inputs.nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
  ];

  hardware.cpu.amd.updateMicrocode = true;
  hardware.amdgpu.initrd.enable = true;

  # Device-specific hidraw permissions for this workstation's peripherals.
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="373b", TAG+="uaccess"

    # VXE NordicMouse 1K receiver.
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f58a", TAG+="uaccess"

    # LEKU NUT65 keyboard.
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="342d", ATTRS{idProduct}=="e51a", TAG+="uaccess"
  '';

  environment.systemPackages = with pkgs; [
    amdgpu_top
    libva-utils
  ];
}
