{
  config,
  lib,
  pkgs,
  ...
}:

let
  btrfsMountPoints = lib.attrNames (
    lib.filterAttrs (_: fs: (fs.fsType or null) == "btrfs") config.fileSystems
  );
in
{
  # Scrub only systems that actually have a Btrfs filesystem. Nixpkgs derives
  # the unique scrub mount points from fileSystems and avoids duplicate work
  # for multiple subvolumes on the same device.
  services.btrfs.autoScrub = lib.mkIf (btrfsMountPoints != [ ]) {
    enable = true;
    interval = "monthly";
  };

  # Apply compression and atime policy only to filesystems that are actually
  # Btrfs; this also works when the installer detects a simpler mount layout.
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
