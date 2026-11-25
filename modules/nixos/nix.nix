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

      # Use only the official Nix cache and the upstream-documented CachyOS mirror.
      # The Lantian endpoint and its signing key are intentionally not trusted.
      substituters = [
        "https://cache.nixos.org"
        "https://cache.xinux.uz"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
      ];

      # Avoid waiting on unresponsive cache connections or stalled downloads.
      accept-flake-config = false;
      connect-timeout = 5;
      stalled-download-timeout = 15;
      download-attempts = 2;
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
