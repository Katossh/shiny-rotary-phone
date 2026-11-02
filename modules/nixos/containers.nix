{ pkgs, ... }:

{
  virtualisation.containers.enable = true;

  virtualisation.podman = {
    enable = true;

    # Use Podman as a regular user; do not create the docker alias or expose
    # compatibility API sockets that would broaden the privilege boundary.
    dockerCompat = false;
    dockerSocket.enable = false;
    networkSocket.enable = false;

    defaultNetwork.settings.dns_enabled = true;
    extraPackages = [ pkgs.fuse-overlayfs ];

    # Avoid automatically deleting stopped containers, images, or networks.
    autoPrune.enable = false;
  };

  # Allocate subordinate UID/GID mappings for rootless user namespaces.
  users.users.katossh.autoSubUidGidRange = true;

  environment.systemPackages = [
    pkgs.podman-compose
  ];
}
