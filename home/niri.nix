{
  config,
  lib,
  pkgs,
  ...
}:

let
  niriMoveWindowWorkspace = pkgs.writeShellApplication {
    name = "niri-move-window-workspace";
    runtimeInputs = [
      pkgs.jq
      pkgs.libnotify
    ];
    text = builtins.readFile ./scripts/niri-move-window-workspace.sh;
  };

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
  home.packages = [ niriMoveWindowWorkspace ];

  wayland.windowManager.niri = {
    enable = true;

    settings = {
      # Ask clients to omit their own titlebars where they support server-side decorations.
      "prefer-no-csd" = { };

      # Keyboard layouts and predictable pointer movement for the VXE mouse.
      clipboard = {
        "disable-primary" = { };
      };

      # Disable the top-left hot corner; keep Overview available through Mod+O.
      gestures = {
        "hot-corners" = {
          off = { };
        };
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
        # Workspaces 1–5 are persistent; Niri supplies an additional dynamic workspace at the end.
        { workspace._args = [ "1" ]; }
        { workspace._args = [ "2" ]; }
        { workspace._args = [ "3" ]; }
        { workspace._args = [ "4" ]; }
        { workspace._args = [ "5" ]; }
        {
          # Games: Steam and its game windows, osu!, and Genshin/Anime Game Launcher.
          window-rule = {
            match._props."app-id" = "(?i)(steam|osu|genshin|anime.?game)";
            "open-on-workspace" = "4";
          };
        }
        {
          # Communication: Discord, Telegram, and LocalSend.
          window-rule = {
            match._props."app-id" = "(?i)(discord|telegram|localsend)";
            "open-on-workspace" = "5";
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
          # Show Noctalia's blurred/tinted wallpaper backdrop in Niri Overview.
          layer-rule = {
            match._props.namespace = "^noctalia-backdrop";
            "place-within-backdrop" = true;
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
          spawn = [ "alacritty" ];
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
        # Open Noctalia's session/power menu without a permanent bar button.
        "Mod+P" = {
          _props.repeat = false;
          _props."hotkey-overlay-title" = "Open session / power menu";
          spawn = [
            "noctalia"
            "msg"
            "panel-toggle"
            "session"
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

        # Open individual Noctalia Control Center panels directly.
        "Mod+N" = {
          _props.repeat = false;
          _props."hotkey-overlay-title" = "Open notifications";
          spawn = [
            "noctalia"
            "msg"
            "panel-toggle"
            "control-center"
            "notifications"
          ];
        };
        "Mod+Shift+W" = {
          _props.repeat = false;
          _props."hotkey-overlay-title" = "Open weather";
          spawn = [
            "noctalia"
            "msg"
            "panel-toggle"
            "control-center"
            "weather"
          ];
        };
        "Mod+Shift+A" = {
          _props.repeat = false;
          _props."hotkey-overlay-title" = "Open calendar";
          spawn = [
            "noctalia"
            "msg"
            "panel-toggle"
            "control-center"
            "calendar"
          ];
        };
        "Mod+Shift+M" = {
          _props.repeat = false;
          _props."hotkey-overlay-title" = "Open media controls";
          spawn = [
            "noctalia"
            "msg"
            "panel-toggle"
            "control-center"
            "media"
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
          _props."hotkey-overlay-title" = "Close focused window";
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

        # Home-row focus layer: H/L moves between columns, K/J between windows in a column.
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
        "Mod+K"."focus-window-up" = { };
        "Mod+J"."focus-window-down" = { };
        "Mod+Home"."focus-column-first" = { };
        "Mod+End"."focus-column-last" = { };

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
        # Home-row movement layer mirrors the focus layer: Ctrl+H/L moves columns,
        # while Ctrl+K/J reorders the focused window vertically within its column.
        "Mod+Ctrl+K" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move window up within column";
          "move-window-up" = { };
        };
        "Mod+Ctrl+J" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move window down within column";
          "move-window-down" = { };
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
        # Alt is the workspace-navigation layer; keep arrow-key aliases as fallbacks.
        "Mod+Alt+Up"."focus-workspace-up" = { };
        "Mod+Alt+Down"."focus-workspace-down" = { };
        "Mod+Alt+K"."focus-workspace-up" = { };
        "Mod+Alt+J"."focus-workspace-down" = { };
        "Mod+Tab" = {
          _props."hotkey-overlay-title" = "Return to previous workspace";
          "focus-workspace-previous" = { };
        };
        "Mod+Ctrl+Page_Down" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move column to next named workspace";
          spawn = [
            "niri-move-window-workspace"
            "column"
            "next"
          ];
        };
        "Mod+Ctrl+Page_Up" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move column to previous named workspace";
          spawn = [
            "niri-move-window-workspace"
            "column"
            "previous"
          ];
        };

        # The five named workspaces are directly addressable; Niri manages its trailing empty workspace.
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
        # Move only the focused window to one of the five named workspaces.
        "Mod+Ctrl+1" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move focused window to workspace 1";
          move-window-to-workspace._args = [ "1" ];
        };
        "Mod+Ctrl+2" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move focused window to workspace 2";
          move-window-to-workspace._args = [ "2" ];
        };
        "Mod+Ctrl+3" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move focused window to workspace 3";
          move-window-to-workspace._args = [ "3" ];
        };
        "Mod+Ctrl+4" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move focused window to workspace 4";
          move-window-to-workspace._args = [ "4" ];
        };
        "Mod+Ctrl+5" = {
          _props."allow-inhibiting" = false;
          _props."hotkey-overlay-title" = "Move focused window to workspace 5";
          move-window-to-workspace._args = [ "5" ];
        };

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
        "Mod+Ctrl+Comma" = {
          _props."hotkey-overlay-title" = "Group window into focused column";
          "consume-window-into-column" = { };
        };
        "Mod+Period" = {
          _props."hotkey-overlay-title" = "Expel window into its own column";
          "expel-window-from-column" = { };
        };
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
        "Mod+Shift+C" = {
          _props."hotkey-overlay-title" = "Pick screen color";
          spawn = [
            "hyprpicker"
            "--autocopy"
          ];
        };
        "Mod+Ctrl+V" = {
          _props."hotkey-overlay-title" = "Toggle floating window";
          "toggle-window-floating" = { };
        };
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
