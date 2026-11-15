{ inputs, pkgs, ... }:

{
  home.packages = [
    # Official OpenCode Desktop; the existing 'opencode' package remains the CLI.
    inputs.opencode-desktop-nix.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop
  ];

  # GitHub CLI remains useful independently of the removed coding agents.
  programs.gh.enable = true;
}
