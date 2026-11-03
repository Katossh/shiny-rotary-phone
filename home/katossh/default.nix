{ pkgs, ... }:

{
  imports = [
    ./niri.nix
    ./noctalia.nix
  ];

  home = {
    username = "katossh";
    homeDirectory = "/home/katossh";
    stateVersion = "26.05";

    packages = with pkgs; [
      brightnessctl
      grim
      playerctl
      pavucontrol
      slurp
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
