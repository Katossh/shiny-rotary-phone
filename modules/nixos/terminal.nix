{ inputs, pkgs, ... }:

{
  # Reuse terminal-dotfiles' supported NixOS package integration instead of
  # parsing its package manifest a second time in this host profile.
  imports = [ (inputs.terminal-dotfiles + "/nix/packages.nix") ];

  # These are NixOS desktop/display-server tools, not part of
  # the portable terminal-dotfiles package manifest.
  environment.systemPackages = with pkgs; [
    alacritty
    kitty
    vim
    xwayland-satellite
  ];
}
