{ pkgs, ... }:

{
  imports = [
    ./gtk.nix
    ./niri.nix
    ./noctalia.nix
    ./terminal-dotfiles.nix
  ];

  services.polkit-gnome.enable = true;

  home = {
    username = "katossh";
    homeDirectory = "/home/katossh";
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
