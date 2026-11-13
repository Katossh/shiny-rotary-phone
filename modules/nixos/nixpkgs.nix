{ lib, ... }:

{
  # Package licensing is a global Nixpkgs evaluation policy, not a property
  # of the development toolchain. Discord is installed through Home Manager.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "code"
      "antigravity-ide"
      "antigravity-ide-fhs"
      "discord"
      "discord-unwrapped"
      "osu-lazer-bin"
      "steam"
      "steam-original"
      "steam-run"
      "steam-unwrapped"
    ];
}
