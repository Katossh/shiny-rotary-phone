{ pkgs, ... }:

let
  bwrapCommand = pkgs.writeShellApplication {
    name = "bwrap";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      BWRAP_BIN="${pkgs.bubblewrap}/bin/bwrap"
      BASH_BIN="${pkgs.bash}/bin/bash"
      ENV_BIN="${pkgs.coreutils}/bin/env"
      ${builtins.readFile ./bwrap.sh}
    '';
  };

  # Preserve direct access to Bubblewrap's low-level CLI for advanced use.
  rawBubblewrap = pkgs.writeShellApplication {
    name = "bubblewrap";
    text = ''
      exec "${pkgs.bubblewrap}/bin/bwrap" "$@"
    '';
  };
in
{
  environment.systemPackages = [
    bwrapCommand
    rawBubblewrap
  ];
}
