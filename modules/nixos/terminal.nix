{ inputs, pkgs, ... }:

{
  # Reuse terminal-dotfiles' supported NixOS package integration instead of
  # parsing its package manifest a second time in Starforge.
  imports = [ (inputs.terminal-dotfiles + "/nix/packages.nix") ];

  # These are Starforge-specific terminal/display-server tools, not part of
  # the portable terminal-dotfiles package manifest.
  environment.systemPackages = with pkgs; [
    alacritty
    kitty
    vim
    xwayland-satellite
  ];
}
