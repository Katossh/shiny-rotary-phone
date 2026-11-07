{ pkgs, starforgeUsername, ... }:

{
  imports = [
    ./preferences.nix
    ./deepcool-digital.nix
    ./gtk.nix
    ./niri.nix
    ./noctalia.nix
    ./terminal-dotfiles.nix
    ./containers.nix
  ];

  home = {
    username = starforgeUsername;
    homeDirectory = "/home/${starforgeUsername}";
    stateVersion = "26.05";

    packages = with pkgs; [
      brightnessctl
      discord
      grim
      playerctl
      pavucontrol
      slurp
      telegram-desktop
      localsend
      opencode
      wl-clipboard
    ];

    file."Pictures/Screenshots/.keep".text = "";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
