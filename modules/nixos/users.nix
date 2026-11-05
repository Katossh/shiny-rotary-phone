{ pkgs, ... }:

{
  users.users.katossh = {
    isNormalUser = true;
    shell = pkgs.zsh;

    # Rootless Podman needs subordinate UID/GID mappings for user namespaces.
    autoSubUidGidRange = true;

    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
}
