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

      # Use the upstream CachyOS kernel cache with its current signing key.
      # The release branch and pinned overlay are kept in sync with these
      # prebuilt artifacts; a cache miss can still fall back to a local build.
      extra-substituters = [
        "https://cache.lantian.pub/lantian"
        "https://noctalia.cachix.org"
      ];
      extra-trusted-public-keys = [
        "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
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
