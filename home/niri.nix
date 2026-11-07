{ config, lib, ... }:

let
  monitorOutputNodes = lib.mapAttrsToList (outputName: monitor: {
    output = {
      _args = [ outputName ];
    }
    // lib.optionalAttrs (monitor.mode != null) { inherit (monitor) mode; }
    // lib.optionalAttrs (monitor.scale != null) { inherit (monitor) scale; }
    // lib.optionalAttrs (monitor.position != null) {
      position._props = monitor.position;
    };
  }) config.starforge.user.desktop.monitors;
in
{
  wayland.windowManager.niri = {
    enable = true;

    settings = {
      # Ask clients to omit their own titlebars where they support server-side decorations.
      "prefer-no-csd" = { };

      # Keyboard layouts and predictable pointer movement for the VXE mouse.
      clipboard = {
        "disable-primary" = { };
      };

      input = {
        keyboard = {
          xkb.layout = config.starforge.user.desktop.niri.keyboardLayout;
          xkb.options = config.starforge.user.desktop.niri.keyboardLayoutOptions;
          "track-layout" = "global";
        };
        mouse."accel-profile" = "flat";
        "focus-follows-mouse" = {
          _props."max-scroll-amount" = "0%";
        };
      };

      layout = {
        gaps = config.starforge.user.desktop.niri.gaps;
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
      # Output nodes are generated from starforge.user.desktop.monitors.
      _children = monitorOutputNodes ++ [
        # Keep five named workspaces available even when they are empty.
        { workspace._args = [ "1" ]; }
        { workspace._args = [ "2" ]; }
        { workspace._args = [ "3" ]; }
        { workspace._args = [ "4" ]; }
        { workspace._args = [ "5" ]; }
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
        "Mod+Shift+Slash" = {
          _props."hotkey-overlay-title" = "Show keyboard shortcuts";
          "show-hotkey-overlay" = { };
        };
        "Mod+Return" = {
          _props."hotkey-overlay-title" = "Open terminal";
          spawn = [ "kitty" ];
        };
        "Mod+Space" = {
          _props."hotkey-overlay-title" = "Open application launcher";
          spawn = [
            "noctalia"
            "msg"
            "panel-toggle"
            "launcher"
          ];
        };
        "Mod+S" = {
          _props."hotkey-overlay-title" = "Open control center";
          spawn = [
            "noctalia"
            "msg"
            "panel-toggle"
            "control-center"
          ];
        };
        "Mod+Comma" = {
          _props."hotkey-overlay-title" = "Open Noctalia settings";
          spawn = [
            "noctalia"
            "msg"
            "settings-toggle"
          ];
        };
        "Super+Alt+L" = {
          _props."hotkey-overlay-title" = "Lock the screen";
          spawn = [
            "noctalia"
            "msg"
            "session"
            "lock"
          ];
        };
        "Mod+O" = {
          _props.repeat = false;
          _props."hotkey-overlay-title" = "Toggle workspace overview";
          "toggle-overview" = { };
        };
        "Mod+Q" = {
          _props.repeat = false;
          _props."hotkey-overlay-title" = "Close focused window";
          "close-window" = { };
        };
        "Alt+F4" = {
          _props.repeat = false;
          _props."hotkey-overlay-title" = null;
          "close-window" = { };
        };

        # Noctalia window switcher: hold Alt to browse, release to activate.
        "Alt+Tab" = {
          _props."hotkey-overlay-title" = "Switch windows";
          spawn = [
            "noctalia"
            "msg"
            "window-switcher"
            "hold"
          ];
        };
        # Keep reverse switching separate from the Alt+Shift XKB layout toggle.
        "Alt+Ctrl+Tab" = {
          _props."hotkey-overlay-title" = "Switch windows backwards";
          spawn = [
            "noctalia"
            "msg"
            "window-switcher"
            "hold"
            "reverse"
          ];
        };

        # Focus columns horizontally; workspace navigation is vertical in Niri.
        "Mod+Left" = {
          _props."hotkey-overlay-title" = "Focus column to the left";
          "focus-column-left" = { };
        };
        "Mod+Right" = {
          _props."hotkey-overlay-title" = "Focus column to the right";
          "focus-column-right" = { };
        };
        "Mod+H"."focus-column-left" = { };
        "Mod+L"."focus-column-right" = { };
        "Mod+Home"."focus-column-first" = { };
        "Mod+End"."focus-column-last" = { };

        # Preserve vertical window focus on Alt-modified bindings.
        "Mod+Alt+Up" = {
          _props."hotkey-overlay-title" = "Focus window above in column";
          "focus-window-up" = { };
        };
        "Mod+Alt+Down" = {
          _props."hotkey-overlay-title" = "Focus window below in column";
          "focus-window-down" = { };
        };
        "Mod+Alt+K"."focus-window-up" = { };
        "Mod+Alt+J"."focus-window-down" = { };

        "Mod+Ctrl+Left" = {
          _props."hotkey-overlay-title" = "Move column left";
          "move-column-left" = { };
        };
        "Mod+Ctrl+Down" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move window down within column";
          "move-window-down" = { };
        };
        "Mod+Ctrl+Up" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move window up within column";
          "move-window-up" = { };
        };
        "Mod+Ctrl+Right" = {
          _props."hotkey-overlay-title" = "Move column right";
          "move-column-right" = { };
        };
        "Mod+Ctrl+H"."move-column-left" = { };
        "Mod+Ctrl+J" = {
          _props."allow-inhibiting" = false;
          "move-window-down" = { };
        };
        "Mod+Ctrl+K" = {
          _props."allow-inhibiting" = false;
          "move-window-up" = { };
        };
        "Mod+Ctrl+L"."move-column-right" = { };
        "Mod+Ctrl+Home"."move-column-to-first" = { };
        "Mod+Ctrl+End"."move-column-to-last" = { };

        "Mod+Shift+Left" = {
          _props."hotkey-overlay-title" = "Focus monitor to the left";
          "focus-monitor-left" = { };
        };
        "Mod+Shift+Down" = {
          _props."hotkey-overlay-title" = "Focus monitor below";
          "focus-monitor-down" = { };
        };
        "Mod+Shift+Up" = {
          _props."hotkey-overlay-title" = "Focus monitor above";
          "focus-monitor-up" = { };
        };
        "Mod+Shift+Right" = {
          _props."hotkey-overlay-title" = "Focus monitor to the right";
          "focus-monitor-right" = { };
        };
        "Mod+Shift+H"."focus-monitor-left" = { };
        "Mod+Shift+J"."focus-monitor-down" = { };
        "Mod+Shift+K"."focus-monitor-up" = { };
        "Mod+Shift+L"."focus-monitor-right" = { };

        "Mod+Page_Down"."focus-workspace-down" = { };
        "Mod+Page_Up"."focus-workspace-up" = { };
        "Mod+Down" = {
          _props."hotkey-overlay-title" = "Focus next workspace";
          "focus-workspace-down" = { };
        };
        "Mod+Up" = {
          _props."hotkey-overlay-title" = "Focus previous workspace";
          "focus-workspace-up" = { };
        };
        "Mod+J"."focus-workspace-down" = { };
        "Mod+K"."focus-workspace-up" = { };
        "Mod+Tab"."focus-workspace-previous" = { };
        "Mod+Ctrl+Page_Down"."move-column-to-workspace-down" = { };
        "Mod+Ctrl+Page_Up"."move-column-to-workspace-up" = { };

        # Keep shortcuts 1-5 tied to the named workspaces, not their current positions.
        "Mod+1" = {
          _props."hotkey-overlay-title" = "Switch to workspace 1";
          focus-workspace._args = [ "1" ];
        };
        "Mod+2" = {
          _props."hotkey-overlay-title" = "Switch to workspace 2";
          focus-workspace._args = [ "2" ];
        };
        "Mod+3" = {
          _props."hotkey-overlay-title" = "Switch to workspace 3";
          focus-workspace._args = [ "3" ];
        };
        "Mod+4" = {
          _props."hotkey-overlay-title" = "Switch to workspace 4";
          focus-workspace._args = [ "4" ];
        };
        "Mod+5" = {
          _props."hotkey-overlay-title" = "Switch to workspace 5";
          focus-workspace._args = [ "5" ];
        };
        "Mod+6".focus-workspace._args = [ 6 ];
        "Mod+7".focus-workspace._args = [ 7 ];
        "Mod+8".focus-workspace._args = [ 8 ];
        "Mod+9".focus-workspace._args = [ 9 ];

        "Mod+Ctrl+1".move-column-to-workspace._args = [ "1" ];
        "Mod+Ctrl+2".move-column-to-workspace._args = [ "2" ];
        "Mod+Ctrl+3".move-column-to-workspace._args = [ "3" ];
        "Mod+Ctrl+4".move-column-to-workspace._args = [ "4" ];
        "Mod+Ctrl+5".move-column-to-workspace._args = [ "5" ];
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
        "Mod+F" = {
          _props."hotkey-overlay-title" = "Maximize column";
          "maximize-column" = { };
        };
        "Mod+M"."maximize-window-to-edges" = { };
        "Mod+Ctrl+F"."expand-column-to-available-width" = { };
        "Mod+Ctrl+C"."center-visible-columns" = { };
        "Mod+BracketLeft"."consume-or-expel-window-left" = { };
        "Mod+BracketRight"."consume-or-expel-window-right" = { };
        "Mod+Ctrl+Comma"."consume-window-into-column" = { };
        "Mod+Period"."expel-window-from-column" = { };
        "Mod+Shift+F" = {
          _props."hotkey-overlay-title" = "Toggle fullscreen";
          "fullscreen-window" = { };
        };
        "Mod+C" = {
          _props."hotkey-overlay-title" = "Center focused column";
          "center-column" = { };
        };
        "Mod+V" = {
          _props."hotkey-overlay-title" = "Open clipboard history";
          spawn = [
            "noctalia"
            "msg"
            "panel-toggle"
            "clipboard"
          ];
        };
        "Mod+Ctrl+V"."toggle-window-floating" = { };
        "Mod+W"."toggle-column-tabbed-display" = { };

        Print = {
          _props."hotkey-overlay-title" = "Interactive screenshot";
          screenshot = { };
        };
        "Ctrl+Print" = {
          _props."hotkey-overlay-title" = "Screenshot current monitor";
          screenshot-screen = { };
        };
        "Alt+Print" = {
          _props."hotkey-overlay-title" = "Screenshot focused window";
          screenshot-window = { };
        };

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
