{ pkgs, starforgeUsername, ... }:

{
  imports = [
    ./preferences.nix
    ./gtk.nix
    ./niri.nix
    ./noctalia.nix
    ./terminal-dotfiles.nix
  ];

  services.polkit-gnome.enable = true;

  home.sessionVariables = {
    DBX_CONTAINER_MANAGER = "podman";
    PODMAN_COMPOSE_PROVIDER = "${pkgs.podman-compose}/bin/podman-compose";
  };

  home = {
    username = starforgeUsername;
    homeDirectory = "/home/${starforgeUsername}";
    stateVersion = "26.05";

    packages = with pkgs; [
      brightnessctl
      discord
      distrobox
      grim
      playerctl
      pavucontrol
      podman-compose
      slurp
      telegram-desktop
      localsend
      wl-clipboard
    ];

    file."Pictures/Screenshots/.keep".text = "";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
