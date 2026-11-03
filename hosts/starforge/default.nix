{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # AMD Ryzen 7000 Raphael iGPU, common AMDGPU support, and AMD P-State.
    inputs.nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd

    ../../modules/nixos/apparmor.nix
    ../../modules/nixos/backup.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/development.nix
    ../../modules/nixos/hardware.nix
    ../../modules/nixos/networking.nix
    ../../modules/nixos/storage.nix
    ../../modules/nixos/snapshots.nix
    ../../modules/nixos/memory.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/security.nix
    ../../modules/nixos/terminal.nix
    ../../modules/nixos/users.nix
    ../../modules/nixos/virtualisation.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    extraSpecialArgs = {
      inherit inputs;
    };

    users.katossh = import ../../home/katossh;
  };

  # Preserve compatibility defaults from the original installation.
  system.stateVersion = "26.05";
}
