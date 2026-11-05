{ config, lib, pkgs, ... }:

let
  username = config.starforge.user.username;
in
{
  options.starforge.user.username = lib.mkOption {
    type = lib.types.strMatching "[a-z_][a-z0-9_-]{0,31}";
    example = "alice";
    description = ''
      Login name for the normal workstation account. This value is shared by
      NixOS, Home Manager, the user's home directory, and user-scoped services.
      Configure it in hosts/workstation/default.nix.
    '';
  };

  assertions = [
    {
      assertion = username != "root";
      message = "starforge.user.username must be a non-root login name.";
    }
  ];

  users.users.${username} = {
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
