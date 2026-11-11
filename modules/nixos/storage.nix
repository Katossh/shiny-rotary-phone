{ pkgs, ... }:

{
  # The root filesystem is Btrfs. The installer generates the mount table from
  # the actual layout; separate /home, /nix, or /var/log mounts are optional.
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
    interval = "monthly";
  };

  # SMART monitoring and NVMe administration concern storage devices rather
  # than a particular partition layout.
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # Keep compression and atime policy on the root Btrfs mount. Do not declare
  # mount options for optional paths: doing so would create incomplete
  # fileSystems entries when a layout keeps those directories on the root.
  fileSystems."/".options = [
    "compress=zstd:1"
    "noatime"
  ];

  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
  ];
}
