{ pkgs, ... }:

{
  # Steam's NixOS module also enables 32-bit graphics support for Proton.
  programs.steam.enable = true;

  # Genshin Impact is distributed on Linux through a community Flatpak launcher.
  services.flatpak.enable = true;

  # Use the AppImage build to retain score submission and multiplayer.
  environment.systemPackages = [
    pkgs.osu-lazer-bin
  ];
}
