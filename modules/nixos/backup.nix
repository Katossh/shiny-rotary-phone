{ pkgs, ... }:

{
  services.restic.backups.starforge = {
    user = "root";
    repositoryFile = "/etc/starforge/restic-repository";
    passwordFile = "/etc/starforge/restic-password";

    paths = [
      "/home/katossh"
      "/etc/nixos"
    ];

    exclude = [
      "/home/katossh/.cache"
      "/home/katossh/.local/share/Trash"
    ];

    # Never initialize a repository implicitly. Retention runs after a
    # successful backup and keeps a useful mix of short- and long-term history.
    initialize = false;
    runCheck = false;
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 12"
      "--keep-yearly 2"
    ];

    # Once the repository and password files exist, run every day.
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };

    # A local repository must be on a separate mounted filesystem. This
    # prevents an absent external disk from silently filling the system disk.
    backupPrepareCommand = ''
      set -eu
      test -s /etc/starforge/restic-repository
      test -s /etc/starforge/restic-password

      IFS= read -r repository < /etc/starforge/restic-repository
      case "$repository" in
        /*)
          test -d "$repository"
          root_device="$("${pkgs.util-linux}/bin/findmnt" --noheadings --output MAJ:MIN --target /)"
          backup_device="$("${pkgs.util-linux}/bin/findmnt" --noheadings --output MAJ:MIN --target "$repository")"
          if [ "$backup_device" = "$root_device" ]; then
            echo "Refusing local Restic repository on the system filesystem: $repository" >&2
            exit 1
          fi
          ;;
      esac
    '';
  };

  # Skip scheduled runs until repository credentials have been provisioned.
  # systemd treats ExecCondition exit status 1 as a skipped service, not failure.
  systemd.services.restic-backups-starforge = {
    serviceConfig.ExecCondition = pkgs.writeShellScript "restic-backup-configured" ''
      if [ ! -s /etc/starforge/restic-repository ] || [ ! -s /etc/starforge/restic-password ]; then
        echo "Restic destination is not configured; skipping scheduled backup."
        exit 1
      fi
    '';
    path = [ pkgs.util-linux ];
  };

  environment.systemPackages = [ pkgs.restic ];
}
