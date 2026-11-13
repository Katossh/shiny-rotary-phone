{ inputs, pkgs, starforgeUsername, ... }:

{
  imports = [
    ./preferences.nix
    ./deepcool-digital.nix
    ./gtk.nix
    ./niri.nix
    ./noctalia.nix
    ./terminal-dotfiles.nix
    ./containers.nix
    ./ai-tools.nix
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
      tor-browser
      localsend
      opencode
      kalker
      wl-clipboard
    ];

    file."Pictures/Screenshots/.keep".text = "";
  };

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
        # Web pages and URL schemes.
        "text/html" = [ "firefox.desktop" ];
        "application/xhtml+xml" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "x-scheme-handler/about" = [ "firefox.desktop" ];
        "x-scheme-handler/unknown" = [ "firefox.desktop" ];

        # File manager.
        "inode/directory" = [ "org.kde.dolphin.desktop" ];
        "application/x-gnome-saved-search" = [ "org.kde.dolphin.desktop" ];
      };
    };
  };
}
