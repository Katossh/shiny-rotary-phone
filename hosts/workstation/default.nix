{ config, inputs, ... }:

{
  networking.hostName = "workstation";

  # The single interactive account shared by NixOS and Home Manager.
  starforge.user.username = "katossh";

  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./displays.nix

    ../../modules/nixos/nixpkgs.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/boot.nix
    ../../modules/nixos/kernel.nix
    ../../modules/nixos/locale.nix

    ../../modules/nixos/networking.nix
    ../../modules/nixos/security.nix
    ../../modules/nixos/apparmor.nix
    ../../modules/security/bubblewrap
    ../../modules/nixos/usbguard.nix
    ../../modules/nixos/users.nix

    ../../modules/nixos/hardware.nix
    ../../modules/nixos/storage.nix
    ../../modules/nixos/snapshots.nix
    ../../modules/nixos/memory.nix
    ../../modules/nixos/power.nix

    ../../modules/nixos/audio.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/development.nix
    ../../modules/nixos/media.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/terminal.nix
    ../../modules/nixos/containers.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/observability.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    extraSpecialArgs = {
      inherit inputs;
      starforgeUsername = config.starforge.user.username;
    };

    users.${config.starforge.user.username} = import ../../home;
  };

  # Preserve compatibility defaults from the original installation.
  system.stateVersion = "26.05";
}
