{ pkgs, ... }:

{
  programs = {
    niri.enable = true;

    firefox = {
      enable = true;
      # Firefox implements PRIMARY-selection paste itself on Linux.
      preferences."middlemouse.paste" = false;
    };
  };

  # Xwayland support and desktop utilities belong to the desktop stack.
  environment.systemPackages = [
    pkgs.chromium
    pkgs.kdePackages.dolphin
    pkgs.seahorse
    pkgs.xwayland-satellite
  ];

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
