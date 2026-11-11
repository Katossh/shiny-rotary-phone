{
  config,
  lib,
  pkgs,
  ...
}:

let
  rootIsBtrfsSubvolume =
    config.fileSystems ? "/"
    && config.fileSystems."/".fsType == "btrfs"
    && builtins.any (option: lib.hasPrefix "subvol=" option) (config.fileSystems."/".options or [ ]);

  homeIsBtrfsSubvolume =
    config.fileSystems ? "/home"
    && config.fileSystems."/home".fsType == "btrfs"
    && builtins.any (option: lib.hasPrefix "subvol=" option) (config.fileSystems."/home".options or [ ]);

  snapperEnabled = rootIsBtrfsSubvolume || homeIsBtrfsSubvolume;

  snapshotDirectories =
    lib.optionals rootIsBtrfsSubvolume [ "/.snapshots" ]
    ++ lib.optionals homeIsBtrfsSubvolume [ "/home/.snapshots" ];

  rootSnapperConfig = lib.optionalAttrs rootIsBtrfsSubvolume {
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
  };

  homeSnapperConfig = lib.optionalAttrs homeIsBtrfsSubvolume {
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
in
{
  services.snapper = lib.mkIf snapperEnabled {
    snapshotInterval = "hourly";
    persistentTimer = true;
    cleanupInterval = "1d";
    configs = rootSnapperConfig // homeSnapperConfig;
  };

  # Snapper requires a dedicated .snapshots Btrfs subvolume for each enabled
  # configuration. Existing non-subvolume directories are never replaced.
  systemd.services = lib.mkIf snapperEnabled {
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

        for snapshots_dir in ${lib.escapeShellArgs snapshotDirectories}; do
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

    snapper-timeline = {
      requires = [ "prepare-btrfs-snapshots.service" ];
      after = [ "prepare-btrfs-snapshots.service" ];
    };

    snapper-cleanup = {
      requires = [ "prepare-btrfs-snapshots.service" ];
      after = [ "prepare-btrfs-snapshots.service" ];
    };
  };

  environment.systemPackages = lib.optionals snapperEnabled [ pkgs.btrfs-progs ];
}
