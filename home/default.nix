{ pkgs, starforgeUsername, ... }:

{
  imports = [
    ./preferences.nix
    ./gtk.nix
    ./niri.nix
    ./noctalia.nix
    ./terminal-dotfiles.nix
    ./containers.nix
  ];

  services.polkit-gnome.enable = true;

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
      wl-clipboard
    ];

    file."Pictures/Screenshots/.keep".text = "";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
