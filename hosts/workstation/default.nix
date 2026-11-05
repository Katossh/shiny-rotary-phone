{ inputs, ... }:

{
  networking.hostName = "workstation";

  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./displays.nix

    ../../modules/nixos/apparmor.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/containers.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/development.nix
    ../../modules/nixos/hardware.nix
    ../../modules/nixos/memory.nix
    ../../modules/nixos/networking.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/observability.nix
    ../../modules/nixos/security.nix
    ../../modules/nixos/usbguard.nix
    ../../modules/nixos/snapshots.nix
    ../../modules/nixos/storage.nix
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
