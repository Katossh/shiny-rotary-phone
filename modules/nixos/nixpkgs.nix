{ lib, ... }:

{
  # Package licensing is a global Nixpkgs evaluation policy, not a property
  # of the development toolchain. Discord is installed through Home Manager.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "code"
      "discord"
      "discord-unwrapped"
    ];
}
