_:

{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Let parallel-capable derivations, including the kernel build, use
      # all 12 logical CPU threads on this workstation.
      cores = 12;

      # Keep builds sandboxed and restrict who can talk to the daemon.
      sandbox = true;
      allowed-users = [
        "root"
        "@wheel"
      ];
      trusted-users = [ "root" ];
      require-sigs = true;

      extra-substituters = [ "https://noctalia.cachix.org" ];
      extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };

    # Collect unreferenced store paths; leave old system generations intact.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    # Deduplicate identical store files once a week, Sunday at 03:45.
    optimise = {
      automatic = true;
      dates = [ "Sun 03:45" ];
    };
  };
}
