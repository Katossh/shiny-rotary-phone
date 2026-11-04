{ pkgs, ... }:

{
  fonts.packages = [
    pkgs.inter
    pkgs.jetbrains-mono
  ];

  programs = {
    niri.enable = true;
    firefox.enable = true;
    amnezia-vpn.enable = true;
  };

  # Keep the system XKB map aligned with Niri's Wayland keyboard configuration.
  services = {
    xserver.xkb = {
      layout = "us,ru";
      options = "grp:alt_shift_toggle";
    };

    gnome.gnome-keyring.enable = true;

    greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
        user = "greeter";
      };
    };
  };

  environment.systemPackages = [
    pkgs.chromium
  ];

  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;

    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];

    config = {
      niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };

      common.default = [ "gtk" ];
    };
  };
}
