{ inputs, pkgs, ... }:

{
  # Steam's NixOS module also enables 32-bit graphics support for Proton.
  programs.steam.enable = true;

  # Install the upstream NixOS launcher module for Genshin Impact.
  imports = [ inputs.aagl.nixosModules.default ];
  nix.settings = inputs.aagl.nixConfig;
  programs.anime-game-launcher.enable = true;

  # Use the AppImage build to retain score submission and multiplayer.
  environment.systemPackages = [
    pkgs.osu-lazer-bin
  ];
}
