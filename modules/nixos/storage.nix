{ ... }:

{
  # The four subvolumes share one encrypted Btrfs filesystem. Keep compression
  # and atime policy consistent across all mounts.
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
}
