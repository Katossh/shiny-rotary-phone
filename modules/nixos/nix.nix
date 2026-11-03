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

    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };
}
