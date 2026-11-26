_:

{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Keep builds sandboxed and restrict who can talk to the daemon.
      sandbox = true;
      allowed-users = [
        "root"
        "@wheel"
      ];
      trusted-users = [ "root" ];
      require-sigs = true;

      # Apply bounded network timeouts and retries to Nix transfers globally.
      connect-timeout = 10;
      stalled-download-timeout = 30;
      filetransfer-retry-attempts = 3;

      # Do not inherit the CachyOS flake's nested nixConfig: it adds the
      # Lantian cache, which is intentionally not used on this workstation.
      # Existing kernel store paths are reused; missing outputs use another
      # configured substituter or are built locally.
      extra-substituters = [
        "https://noctalia.cachix.org"
      ];
      extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };

    # Collect unreferenced store paths; system generations remain available
    # as rollback targets until they are removed explicitly.
    gc = {
      automatic = true;
      dates = "weekly";
    };

    # Deduplicate identical store files once a week, Sunday at 03:45.
    optimise = {
      automatic = true;
      dates = [ "Sun 03:45" ];
    };
  };
}
