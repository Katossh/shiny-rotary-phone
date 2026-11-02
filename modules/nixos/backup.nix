{ pkgs, ... }:

{
  # Keep the backup definition declarative, but do not schedule it until the
  # host has a verified local or remote repository and password file.
  services.restic.backups.starforge = {
    user = "root";
    repositoryFile = "/etc/starforge/restic-repository";
    passwordFile = "/etc/starforge/restic-password";

    paths = [
      "/home/katossh"
      "/etc/nixos"
    ];

    # These are reproducible or disposable and can otherwise dominate backup
    # size. User files and Git repositories remain.
    exclude = [
      "/home/katossh/.cache"
      "/home/katossh/.local/share/Trash"
    ];

    initialize = false;
    runCheck = false;
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 12"
      "--keep-yearly 2"
    ];

    # An explicit manual start is required until backup storage is configured.
    timerConfig = null;

    # Fail early if the host-local repository/password files have not yet been
    # provisioned. The repository itself may be local or remote.
    backupPrepareCommand = ''
      test -s /etc/starforge/restic-repository
      test -s /etc/starforge/restic-password
    '';
  };

  environment.systemPackages = [
    pkgs.restic
  ];
}
