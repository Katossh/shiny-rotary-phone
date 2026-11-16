{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Inspect only the mount points supported by this workstation profile.
  # Enumerating config.fileSystems here would make this module depend on
  # the option set it is extending and cause infinite recursion.
  btrfsMountPoints = lib.filter
    (mountPoint: (config.fileSystems.${mountPoint}.fsType or null) == "btrfs")
    [
      "/"
      "/home"
      "/nix"
      "/var/log"
    ];
in
{
  # Scrub only the Btrfs filesystems that are actually configured.
  services.btrfs.autoScrub = lib.mkIf (btrfsMountPoints != [ ]) {
    enable = true;
    fileSystems = btrfsMountPoints;
    interval = "monthly";
  };

  # Apply compression and atime policy only to detected Btrfs mount points.
  fileSystems = lib.genAttrs btrfsMountPoints (_: {
    options = [
      "compress=zstd:1"
      "noatime"
    ];
  });

  # SMART monitoring and NVMe administration concern storage devices rather
  # than general hardware capability.
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
  ];
}
