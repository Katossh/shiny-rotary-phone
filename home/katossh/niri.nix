_:

{
  wayland.windowManager.niri = {
    enable = true;

    settings = {
      # Ask clients to omit their own titlebars where they support server-side decorations.
      "prefer-no-csd" = { };

      # Keyboard layouts and predictable pointer movement for the VXE mouse.
      input = {
        keyboard = {
          xkb.layout = "us,ru";
          xkb.options = "grp:alt_shift_toggle";
          "track-layout" = "global";
        };
        mouse."accel-profile" = "flat";
      };

      layout = {
        gaps = 12;
        "center-focused-column" = "on-overflow";
        "default-column-width" = {
          proportion = 0.5;
        };
        "preset-column-widths" = {
          _children = [
            { proportion = 0.25; }
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
            { proportion = 0.75; }
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

      # Apply rounded corners to ordinary application windows.
      "window-rule"._children = [
        {
          match._props."app-id" = ".*";
          "geometry-corner-radius" = 14;
          "clip-to-geometry" = true;
        }
      ];

      # Niri 26.04 compositor blur; keep it moderate on the integrated Radeon GPU.
      blur = {
        passes = 2;
        offset = 3.0;
        noise = 0.03;
        saturation = 1.0;
      };

      # Permit Noctalia notification actions and activation requests.
      debug."honor-xdg-activation-with-invalid-serial" = { };

      "screenshot-path" = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      # Repeated top-level KDL nodes must use root _children.
      _children = [
        {
          # Xiaomi 34-inch ultrawide: choose the highest advertised 3440x1440 mode.
          # This should select the monitor's 180 Hz mode when advertised.
          output = {
            _args = [ "DP-1" ];
            mode = "3440x1440";
            # FreeSync / VRR intentionally disabled.
          };
        }
        {
          # Float Noctalia's settings window.
          window-rule = {
            match._props."app-id" = "^dev\\.noctalia\\.Noctalia$";
            "open-floating" = true;
            "default-column-width".fixed = 1080;
            "default-window-height".fixed = 920;
          };
        }
        {
          # Keep Noctalia surfaces blurring the content behind them, not wallpaper xray.
          layer-rule = {
            match._props.namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd)$";
            "background-effect" = {
              xray = false;
            };
          };
        }
        {
          # Enable blur specifically for Noctalia's window switcher.
          layer-rule = {
            match._props.namespace = "^noctalia-window-switcher$";
            "background-effect" = {
              blur = true;
              xray = false;
            };
          };
        }
      ];

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
        "Mod+O" = {
          _props.repeat = false;
          "toggle-overview" = { };
        };
        "Mod+Q" = {
          _props.repeat = false;
          "close-window" = { };
        };
        "Alt+F4" = {
          _props.repeat = false;
          "close-window" = { };
        };

        # Noctalia window switcher: hold Alt to browse, release to activate.
        "Alt+Tab".spawn = [
          "noctalia"
          "msg"
          "window-switcher"
          "hold"
        ];
        "Alt+Shift+Tab".spawn = [
          "noctalia"
          "msg"
          "window-switcher"
          "hold"
          "reverse"
        ];

        "Mod+Left"."focus-column-left" = { };
        "Mod+Down"."focus-window-down" = { };
        "Mod+Up"."focus-window-up" = { };
        "Mod+Right"."focus-column-right" = { };
        "Mod+H"."focus-column-left" = { };
        "Mod+J"."focus-window-down" = { };
        "Mod+K"."focus-window-up" = { };
        "Mod+L"."focus-column-right" = { };
        "Mod+Home"."focus-column-first" = { };
        "Mod+End"."focus-column-last" = { };

        "Mod+Ctrl+Left"."move-column-left" = { };
        "Mod+Ctrl+Down"."move-window-down" = { };
        "Mod+Ctrl+Up"."move-window-up" = { };
        "Mod+Ctrl+Right"."move-column-right" = { };
        "Mod+Ctrl+H"."move-column-left" = { };
        "Mod+Ctrl+J"."move-window-down" = { };
        "Mod+Ctrl+K"."move-window-up" = { };
        "Mod+Ctrl+L"."move-column-right" = { };
        "Mod+Ctrl+Home"."move-column-to-first" = { };
        "Mod+Ctrl+End"."move-column-to-last" = { };

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
        "Mod+Ctrl+Shift+R"."switch-preset-window-height" = { };
        "Mod+Minus".set-column-width._args = [ "-10%" ];
        "Mod+Equal".set-column-width._args = [ "+10%" ];
        "Mod+Shift+Minus".set-window-height._args = [ "-10%" ];
        "Mod+Shift+Equal".set-window-height._args = [ "+10%" ];
        "Mod+F"."maximize-column" = { };
        "Mod+M"."maximize-window-to-edges" = { };
        "Mod+Ctrl+F"."expand-column-to-available-width" = { };
        "Mod+Ctrl+C"."center-visible-columns" = { };
        "Mod+BracketLeft"."consume-or-expel-window-left" = { };
        "Mod+BracketRight"."consume-or-expel-window-right" = { };
        "Mod+Ctrl+Comma"."consume-window-into-column" = { };
        "Mod+Period"."expel-window-from-column" = { };
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

        # Use Noctalia IPC so volume changes display its OSD.
        "XF86AudioRaiseVolume" = {
          _props."allow-when-locked" = true;
          spawn = [
            "noctalia"
            "msg"
            "volume-up"
          ];
        };
        "XF86AudioLowerVolume" = {
          _props."allow-when-locked" = true;
          spawn = [
            "noctalia"
            "msg"
            "volume-down"
          ];
        };
        "XF86AudioMute" = {
          _props."allow-when-locked" = true;
          _props.repeat = false;
          spawn = [
            "noctalia"
            "msg"
            "volume-mute"
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

        # Noctalia handles brightness and displays the matching OSD.
        "XF86MonBrightnessUp" = {
          _props."allow-when-locked" = true;
          spawn = [
            "noctalia"
            "msg"
            "brightness-up"
          ];
        };
        "XF86MonBrightnessDown" = {
          _props."allow-when-locked" = true;
          spawn = [
            "noctalia"
            "msg"
            "brightness-down"
          ];
        };
      };
    };
  };
}
