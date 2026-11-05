{ config, inputs, lib, pkgs, ... }:

{
  # terminal-dotfiles owns its complete configuration lifecycle. Home Manager
  # only invokes its native installer; it does not parse manifests, rewrite
  # shell files, or recreate theme/plugin links itself.
  home.activation.installTerminalDotfiles =
    lib.hm.dag.entryAfter
      [
        "writeBoundary"
        "linkGeneration"
      ]
      ''
        # Home Manager activation does not necessarily inherit the interactive
        # login-shell PATH. Make the installer's runtime dependencies explicit.
        export HOME="${config.home.homeDirectory}"
        export XDG_CONFIG_HOME="${config.home.homeDirectory}/.config"
        export XDG_DATA_HOME="${config.home.homeDirectory}/.local/share"
        export PATH="${lib.makeBinPath (with pkgs; [
          coreutils
          findutils
          gawk
          git
          gnugrep
          gnused
          tmux
        ])}:$PATH"

        # Do not inherit an offline/config-only setting from the caller. The
        # installer must restore Oh My Zsh and its plugins during activation.
        unset DOTS_SKIP_DOWNLOADS
        export DOTS_GIT_CLONE_RETRIES=5

        run ${pkgs.bash}/bin/bash \
          ${inputs.terminal-dotfiles}/bin/dots install --no-packages --yes
      '';
}
