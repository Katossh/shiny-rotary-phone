{ pkgs, ... }:

{
  imports = [
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
      wl-clipboard
    ];

    file = {
      # Ensure the directory targeted by Niri's screenshot-path exists.
      "Pictures/Screenshots/.keep".text = "";

      # LocalShare is a browser-based LAN sharing tool; expose it as a Chromium app.
      ".local/share/applications/localshare.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=LocalShare
        GenericName=Local file sharing
        Comment=Share files and text with devices on your local network
        Exec=${pkgs.chromium}/bin/chromium --app=https://www.local-share.com
        Icon=chromium
        Terminal=false
        Categories=Network;FileTransfer;
        StartupNotify=true
      '';
    };
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
