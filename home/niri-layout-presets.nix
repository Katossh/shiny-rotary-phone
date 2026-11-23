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
        "hotkey-overlay-title" = "Apply focused main + tab stack layout (65 / 35)";
      };
      spawn = [
        "niri-layout-preset"
        "focus-stack"
      ];
    };
    "Mod+Alt+2" = {
      _props = {
        repeat = false;
        "allow-inhibiting" = false;
        "hotkey-overlay-title" = "Apply two-window layout (50 / 50)";
      };
      spawn = [
        "niri-layout-preset"
        "double"
      ];
    };
    "Mod+Alt+3" = {
      _props = {
        repeat = false;
        "allow-inhibiting" = false;
        "hotkey-overlay-title" = "Apply three-window layout (33 / 33 / 33)";
      };
      spawn = [
        "niri-layout-preset"
        "triple"
      ];
    };
    "Mod+Alt+4" = {
      _props = {
        repeat = false;
        "allow-inhibiting" = false;
        "hotkey-overlay-title" = "Apply four-window layout (25 / 25 / 25 / 25)";
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
        "hotkey-overlay-title" = "Apply centered main + references layout (20 / 60 / 20)";
      };
      spawn = [
        "niri-layout-preset"
        "references"
      ];
    };
  };
}
