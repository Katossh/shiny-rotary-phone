{
  config,
  lib,
  pkgs,
  ...
}:

let
  rootIsBtrfs = config.fileSystems."/".fsType == "btrfs";
in
{
  # Btrfs maintenance is enabled only when the generated root filesystem is
  # actually Btrfs. Other supported root filesystems remain valid install targets.
  services.btrfs.autoScrub = lib.mkIf rootIsBtrfs {
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

  fileSystems."/".options = lib.mkIf rootIsBtrfs [
    "compress=zstd:1"
    "noatime"
  ];

  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
  ];
}
