{ pkgs, ... }:

{
  # The four subvolumes share one encrypted Btrfs filesystem. Keep compression
  # and atime policy consistent across all mounts.
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
    interval = "monthly";
  };

  # SMART monitoring and NVMe administration concern storage devices rather
  # than general hardware capability.
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  fileSystems = {
    "/".options = [
      "compress=zstd:1"
      "noatime"
    ];

    "/home".options = [
      "compress=zstd:1"
      "noatime"
    ];

    "/nix".options = [
      "compress=zstd:1"
      "noatime"
    ];

    "/var/log".options = [
      "compress=zstd:1"
      "noatime"
    ];
  };

  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
  ];
}
