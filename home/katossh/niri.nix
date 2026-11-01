{ ... }:

{
  wayland.windowManager.niri = {
    enable = true;

    settings = {
      "prefer-no-csd" = { };

      layout = {
        gaps = 8;
        "center-focused-column" = "never";
        "default-column-width" = {
          proportion = 0.5;
        };
        "preset-column-widths" = {
          _children = [
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
          ];
        };
        "focus-ring" = {
          width = 2;
          "active-color" = "#89b4fa";
          "inactive-color" = "#585b70";
        };
        shadow = {
          on = { };
          softness = 30;
          spread = 5;
          offset._props = {
            x = 0;
            y = 5;
          };
          color = "#0007";
        };
      };

      "window-rule" = {
        _children = [
          {
            match._props."app-id" = ".*";
            "geometry-corner-radius" = 10;
            "clip-to-geometry" = true;
          }
        ];
      };

      "screenshot-path" = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      binds = {
        "Mod+Shift+Slash"."show-hotkey-overlay" = { };
        "Mod+Return".spawn = [ "kitty" ];
        "Mod+Space".spawn = [
          "noctalia"
          "msg"
          "panel-toggle"
          "launcher"
        ];
        "Mod+S".spawn = [
          "noctalia"
          "msg"
          "panel-toggle"
          "control-center"
        ];
        "Mod+Comma".spawn = [
          "noctalia"
          "msg"
          "settings-toggle"
        ];
        "Super+Alt+L".spawn = [
          "noctalia"
          "msg"
          "session"
          "lock"
        ];
        "Mod+O"."toggle-overview" = { };
        "Mod+Q"."close-window" = { };
        "Alt+F4"."close-window" = { };

        "Mod+Left"."focus-column-left" = { };
        "Mod+Down"."focus-window-down" = { };
        "Mod+Up"."focus-window-up" = { };
        "Mod+Right"."focus-column-right" = { };
        "Mod+H"."focus-column-left" = { };
        "Mod+J"."focus-window-down" = { };
        "Mod+K"."focus-window-up" = { };
        "Mod+L"."focus-column-right" = { };

        "Mod+Ctrl+Left"."move-column-left" = { };
        "Mod+Ctrl+Down"."move-window-down" = { };
        "Mod+Ctrl+Up"."move-window-up" = { };
        "Mod+Ctrl+Right"."move-column-right" = { };
        "Mod+Ctrl+H"."move-column-left" = { };
        "Mod+Ctrl+J"."move-window-down" = { };
        "Mod+Ctrl+K"."move-window-up" = { };
        "Mod+Ctrl+L"."move-column-right" = { };

        "Mod+Shift+Left"."focus-monitor-left" = { };
        "Mod+Shift+Down"."focus-monitor-down" = { };
        "Mod+Shift+Up"."focus-monitor-up" = { };
        "Mod+Shift+Right"."focus-monitor-right" = { };
        "Mod+Shift+H"."focus-monitor-left" = { };
        "Mod+Shift+J"."focus-monitor-down" = { };
        "Mod+Shift+K"."focus-monitor-up" = { };
        "Mod+Shift+L"."focus-monitor-right" = { };

        "Mod+Page_Down"."focus-workspace-down" = { };
        "Mod+Page_Up"."focus-workspace-up" = { };
        "Mod+Tab"."focus-workspace-previous" = { };
        "Mod+Ctrl+Page_Down"."move-column-to-workspace-down" = { };
        "Mod+Ctrl+Page_Up"."move-column-to-workspace-up" = { };

        "Mod+1".focus-workspace._args = [ 1 ];
        "Mod+2".focus-workspace._args = [ 2 ];
        "Mod+3".focus-workspace._args = [ 3 ];
        "Mod+4".focus-workspace._args = [ 4 ];
        "Mod+5".focus-workspace._args = [ 5 ];
        "Mod+6".focus-workspace._args = [ 6 ];
        "Mod+7".focus-workspace._args = [ 7 ];
        "Mod+8".focus-workspace._args = [ 8 ];
        "Mod+9".focus-workspace._args = [ 9 ];

        "Mod+Ctrl+1".move-column-to-workspace._args = [ 1 ];
        "Mod+Ctrl+2".move-column-to-workspace._args = [ 2 ];
        "Mod+Ctrl+3".move-column-to-workspace._args = [ 3 ];
        "Mod+Ctrl+4".move-column-to-workspace._args = [ 4 ];
        "Mod+Ctrl+5".move-column-to-workspace._args = [ 5 ];
        "Mod+Ctrl+6".move-column-to-workspace._args = [ 6 ];
        "Mod+Ctrl+7".move-column-to-workspace._args = [ 7 ];
        "Mod+Ctrl+8".move-column-to-workspace._args = [ 8 ];
        "Mod+Ctrl+9".move-column-to-workspace._args = [ 9 ];

        "Mod+R"."switch-preset-column-width" = { };
        "Mod+Shift+R"."switch-preset-column-width-back" = { };
        "Mod+Ctrl+R"."reset-window-height" = { };
        "Mod+F"."maximize-column" = { };
        "Mod+Shift+F"."fullscreen-window" = { };
        "Mod+C"."center-column" = { };
        "Mod+V"."toggle-window-floating" = { };
        "Mod+Shift+V"."switch-focus-between-floating-and-tiling" = { };
        "Mod+W"."toggle-column-tabbed-display" = { };

        Print.screenshot = { };
        "Ctrl+Print".screenshot-screen = { };
        "Alt+Print".screenshot-window = { };

        "Mod+Escape" = {
          _props."allow-inhibiting" = false;
          "toggle-keyboard-shortcuts-inhibit" = { };
        };

        "Mod+Shift+E".quit = { };
        "Mod+Shift+P"."power-off-monitors" = { };

        "XF86AudioRaiseVolume" = {
          _props."allow-when-locked" = true;
          spawn = [
            "wpctl"
            "set-volume"
            "@DEFAULT_AUDIO_SINK@"
            "5%+"
            "-l"
            "1.0"
          ];
        };
        "XF86AudioLowerVolume" = {
          _props."allow-when-locked" = true;
          spawn = [
            "wpctl"
            "set-volume"
            "@DEFAULT_AUDIO_SINK@"
            "5%-"
          ];
        };
        "XF86AudioMute" = {
          _props."allow-when-locked" = true;
          spawn = [
            "wpctl"
            "set-mute"
            "@DEFAULT_AUDIO_SINK@"
            "toggle"
          ];
        };
        "XF86AudioMicMute" = {
          _props."allow-when-locked" = true;
          spawn = [
            "wpctl"
            "set-mute"
            "@DEFAULT_AUDIO_SOURCE@"
            "toggle"
          ];
        };
        "XF86AudioPlay".spawn = [
          "playerctl"
          "play-pause"
        ];
        "XF86AudioPause".spawn = [
          "playerctl"
          "play-pause"
        ];
        "XF86AudioStop".spawn = [
          "playerctl"
          "stop"
        ];
        "XF86AudioPrev".spawn = [
          "playerctl"
          "previous"
        ];
        "XF86AudioNext".spawn = [
          "playerctl"
          "next"
        ];

        "XF86MonBrightnessUp".spawn = [
          "brightnessctl"
          "--class=backlight"
          "set"
          "+5%"
        ];
        "XF86MonBrightnessDown".spawn = [
          "brightnessctl"
          "--class=backlight"
          "set"
          "5%-"
        ];
      };
    };
  };
}
