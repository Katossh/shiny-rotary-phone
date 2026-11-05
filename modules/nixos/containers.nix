{ ... }:

{
  # Podman is the primary OCI runtime. The Docker alias is CLI compatibility
  # only; do not expose a rootful Docker-compatible API socket by default.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;

    # Enable service-name DNS on the default bridge network for Compose stacks.
    defaultNetwork.settings.dns_enabled = true;
  };
}