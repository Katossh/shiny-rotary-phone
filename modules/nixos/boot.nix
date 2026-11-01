{ pkgs, ... }:

{
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = false;
    };

    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  boot.supportedFilesystems = [ "btrfs" ];

  # Keep the original kernel policy during the structural refactor.
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
