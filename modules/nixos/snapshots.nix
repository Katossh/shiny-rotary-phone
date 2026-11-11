{
  config,
  lib,
  pkgs,
  ...
}:

let
  isBtrfs = mountPoint: (config.fileSystems.${mountPoint}.fsType or null) == "btrfs";
  rootIsBtrfs = isBtrfs "/";
  # A directory on the root filesystem is not automatically a Btrfs
  # subvolume. Only snapshot /home when it has its own Btrfs mount.
  homeIsBtrfs = (config.fileSystems ? "/home") && isBtrfs "/home";

  snapshotConfigs =
    lib.optionalAttrs rootIsBtrfs {
      root = {
        SUBVOLUME = "/";
        FSTYPE = "btrfs";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 6;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 4;
        TIMELINE_LIMIT_MONTHLY = 6;
        TIMELINE_LIMIT_YEARLY = 0;
      };
    }
    // lib.optionalAttrs homeIsBtrfs {
      home = {
        SUBVOLUME = "/home";
        FSTYPE = "btrfs";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 6;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 4;
        TIMELINE_LIMIT_MONTHLY = 6;
        TIMELINE_LIMIT_YEARLY = 0;
      };
    };

  snapshotDirs =
    (lib.optional rootIsBtrfs "/.snapshots") ++ (lib.optional homeIsBtrfs "/home/.snapshots");
in
{
  # Snapper is enabled only for Btrfs-backed root/home mount points. Ext4 or
  # other supported root layouts do not receive invalid Btrfs snapshot jobs.
  services.snapper = lib.mkIf (snapshotConfigs != { }) {
    snapshotInterval = "hourly";
    persistentTimer = true;
    cleanupInterval = "1d";
    configs = snapshotConfigs;
  };

  # Snapper needs a dedicated .snapshots Btrfs subvolume in each configured
  # subvolume. Existing ordinary directories are never replaced.
  systemd.services = lib.mkIf (snapshotDirs != [ ]) {
    prepare-btrfs-snapshots = {
      description = "Prepare Btrfs subvolumes required by Snapper";
      wantedBy = [ "multi-user.target" ];
      requires = [ "local-fs.target" ];
      after = [ "local-fs.target" ];
      before = [
        "snapper-timeline.service"
        "snapper-cleanup.service"
      ];
      path = [ pkgs.btrfs-progs ];
      enableStrictShellChecks = true;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        for snapshots_dir in ${lib.concatStringsSep " " (map lib.escapeShellArg snapshotDirs)}; do
          if btrfs subvolume show "$snapshots_dir" >/dev/null 2>&1; then
            continue
          fi

          if [ -e "$snapshots_dir" ]; then
            echo "Refusing to replace existing non-subvolume path: $snapshots_dir" >&2
            exit 1
          fi

          btrfs subvolume create "$snapshots_dir"
          ${pkgs.coreutils}/bin/chmod 0700 "$snapshots_dir"
        done
      '';
    };

    # Both Snapper jobs must wait until their snapshot destinations exist.
    snapper-timeline = {
      requires = [ "prepare-btrfs-snapshots.service" ];
      after = [ "prepare-btrfs-snapshots.service" ];
    };

    snapper-cleanup = {
      requires = [ "prepare-btrfs-snapshots.service" ];
      after = [ "prepare-btrfs-snapshots.service" ];
    };
  };

  environment.systemPackages = [ pkgs.btrfs-progs ];
}
