{ pkgs, ... }:

{
  # Keep the user-facing container tools and their provider selection together.
  home.sessionVariables = {
    DBX_CONTAINER_MANAGER = "podman";
    PODMAN_COMPOSE_PROVIDER = "${pkgs.podman-compose}/bin/podman-compose";
  };

  home.packages = with pkgs; [
    distrobox
    podman-compose
  ];
}
