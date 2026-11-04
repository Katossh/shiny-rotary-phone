{ pkgs, ... }:

{
  imports = [
    ./niri.nix
    ./noctalia.nix
    ./terminal-dotfiles.nix
  ];

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
      wl-clipboard
    ];

    # Ensure the directory targeted by Niri's screenshot-path exists.
    file."Pictures/Screenshots/.keep".text = "";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
