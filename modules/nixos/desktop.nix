{ pkgs, ... }:

{
  programs = {
    niri.enable = true;
    firefox.enable = true;
    amnezia-vpn.enable = true;
  };

  # Keep the system XKB layout aligned with Niri's Wayland keyboard config.
  services.xserver.xkb.layout = "us,ru";

  environment.systemPackages = [
    pkgs.chromium
  ];

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
      user = "greeter";
    };
  };

  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
