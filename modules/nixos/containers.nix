_:

{
  # Podman is the primary OCI runtime. The Docker alias is CLI compatibility
  # only; do not expose a rootful Docker-compatible API socket by default.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;

    # Enable service-name DNS on the default bridge network for Compose stacks.
    defaultNetwork.settings.dns_enabled = true;
  };

  # The Podman package ships this rootless user unit. It starts containers
  # whose restart policy is "always" or "unless-stopped" after each boot.
  systemd.user.services.podman-restart.wantedBy = [ "default.target" ];
}
