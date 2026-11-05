{ pkgs, ... }:

{
  services.snapper = {
    snapshotInterval = "hourly";
    persistentTimer = true;
    cleanupInterval = "1d";

    configs = {
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
  };

  # Snapper requires a dedicated .snapshots Btrfs subvolume inside each
  # configured subvolume. Create it once after local filesystems are mounted.
  # Existing non-subvolume directories are never replaced automatically.
  systemd.services = {
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

        for snapshots_dir in /.snapshots /home/.snapshots; do
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
