{ inputs, pkgs, ... }:

{
  imports = [
    (inputs.terminal-dotfiles + "/nix/packages.nix")
  ];

  # Kitty and Zsh configuration remain owned by terminal-dotfiles.
  environment.systemPackages = with pkgs; [
    kitty
    vim
    xwayland-satellite
  ];
}
