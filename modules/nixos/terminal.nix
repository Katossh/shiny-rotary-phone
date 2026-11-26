{ inputs, pkgs, ... }:

{
  # Reuse terminal-dotfiles' supported NixOS package integration instead of
  # parsing its package manifest a second time in this host profile.
  imports = [ (inputs.terminal-dotfiles + "/nix/packages.nix") ];

  # Alacritty is the default terminal; Kitty remains available as an alternative.
  environment.sessionVariables.TERMINAL = "alacritty";

  # Terminal emulators and the interactive editor are host packages rather
  # than part of the portable terminal-dotfiles package manifest.
  environment.systemPackages = with pkgs; [
    alacritty
    kitty
    vim

    # Nix workflow utilities.
    nix-your-shell
    bottom
  ];

  # Use nix-index-database's prebuilt command index while keeping Comma's
  # Zsh command-not-found integration.
  programs.comma = {
    enable = true;
    package =
      inputs.nix-index-database.packages.${pkgs.stdenv.hostPlatform.system}."comma-with-db";
    enableZshIntegration = true;
  };

  # Keep the user's configured Zsh when entering nix develop, nix shell,
  # and nix-shell instead of falling back to Bash.
  programs.zsh.interactiveShellInit = ''
    if command -v nix-your-shell >/dev/null 2>&1; then
      nix-your-shell zsh | source /dev/stdin
    fi
  '';
}
