{ pkgs, ... }:

{
  imports = [
    ./niri.nix
    ./noctalia.nix
  ];

  home.username = "katossh";
  home.homeDirectory = "/home/katossh";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    brightnessctl
    grim
    playerctl
    pavucontrol
    slurp
    wl-clipboard
  ];

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
