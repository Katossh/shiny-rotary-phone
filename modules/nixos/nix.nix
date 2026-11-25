{ inputs, ... }:

let
  # Nix does not propagate nixConfig from nested flake inputs into the root
  # flake. Read the cache declarations from the exact locked upstream source
  # instead of duplicating its substituter URLs and signing keys here.
  cachyosNixConfig = (import (inputs.nix-cachyos-kernel.outPath + "/flake.nix")).nixConfig;
in
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

      extra-substituters = [
        "https://noctalia.cachix.org"
      ]
      ++ (cachyosNixConfig.extra-substituters or [ ]);
      extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ]
      ++ (cachyosNixConfig.extra-trusted-public-keys or [ ]);
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
