{ pkgs, ... }:

{
  programs = {
    niri.enable = true;

    firefox = {
      enable = true;
      # Keep the unmodified Nixpkgs package so CI and workstations can use
      # the upstream binary cache instead of rebuilding Firefox from source.
      # Firefox implements PRIMARY-selection paste itself on Linux.
      preferences."middlemouse.paste" = false;
    };
  };

  # Install Blender system-wide so its executable is on the global PATH
  # and its upstream desktop entry is visible to every desktop launcher.
  # The Nixpkgs package provides both /bin/blender and blender.desktop.
  environment.systemPackages = [
    pkgs.blender
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
