{ pkgs, ... }:

{
  # System-wide fonts are shared by Niri, Noctalia, GTK applications and
  # terminal applications; they are not part of the desktop service module.
  fonts.packages = [
    pkgs.inter
    pkgs.jetbrains-mono
  ];
}
