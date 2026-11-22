{ pkgs, ... }:

let
  niriLayoutPreset = pkgs.writeShellApplication {
    name = "niri-layout-preset";
    runtimeInputs = [
      pkgs.jq
      pkgs.libnotify
    ];
    text = builtins.readFile ./scripts/niri-layout-preset.sh;
  };
in
{
  home.packages = [ niriLayoutPreset ];

  wayland.windowManager.niri.settings.binds = {
    "Mod+Alt+1" = {
      _props = {
        repeat = false;
        "allow-inhibiting" = false;
        "hotkey-overlay-title" = "Apply developer layout (50 / 25 / 25)";
      };
      spawn = [
        "niri-layout-preset"
        "developer"
      ];
    };
    "Mod+Alt+2" = {
      _props = {
        repeat = false;
        "allow-inhibiting" = false;
        "hotkey-overlay-title" = "Apply triple layout (33 / 33 / 33)";
      };
      spawn = [
        "niri-layout-preset"
        "triple"
      ];
    };
    "Mod+Alt+3" = {
      _props = {
        repeat = false;
        "allow-inhibiting" = false;
        "hotkey-overlay-title" = "Apply asymmetric layout (25 / 37.5 / 37.5)";
      };
      spawn = [
        "niri-layout-preset"
        "asymmetric"
      ];
    };
    "Mod+Alt+4" = {
      _props = {
        repeat = false;
        "allow-inhibiting" = false;
        "hotkey-overlay-title" = "Apply quad layout (25 / 25 / 25 / 25)";
      };
      spawn = [
        "niri-layout-preset"
        "quad"
      ];
    };
    "Mod+Alt+5" = {
      _props = {
        repeat = false;
        "allow-inhibiting" = false;
        "hotkey-overlay-title" = "Apply main + references layout (60 / 20 / 20)";
      };
      spawn = [
        "niri-layout-preset"
        "references"
      ];
    };
  };
}
