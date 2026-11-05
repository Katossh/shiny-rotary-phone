{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  # terminal-dotfiles owns its complete configuration lifecycle. Home Manager
  # only invokes its native installer; it does not parse manifests, rewrite
  # shell files, or recreate theme/plugin links itself.
  home.activation.installTerminalDotfiles =
    lib.hm.dag.entryAfter [
      "writeBoundary"
      "linkGeneration"
    ] ''
      DOTS_SKIP_DOWNLOADS=0 run \
        ${pkgs.bash}/bin/bash \
        ${inputs.terminal-dotfiles}/bin/dots install --no-packages --yes
    '';
}
