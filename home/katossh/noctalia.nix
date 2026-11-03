{ inputs, ... }:

{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    checkConfig = true;

    settings = {
      # Require authentication after locking and lock automatically before sleep.
      lockscreen = {
        enabled = true;
        lock_before_suspend = true;
        grace_period_seconds = 0;
      };

      # Lock after ten idle minutes; turn displays off after fifteen.
      # Noctalia respects active idle inhibitors (for example, video playback).
      idle = {
        behavior_order = [
          "lock"
          "screen-off"
        ];
        pre_action_fade_seconds = 2.0;
        behavior = {
          lock = {
            enabled = true;
            timeout = 600;
            action = "lock";
          };
          "screen-off" = {
            enabled = true;
            timeout = 900;
            action = "screen_off";
          };
        };
      };
      shell = {
        font_family = "JetBrainsMono Nerd Font";
        settings_show_advanced = true;
        launch_apps_as_systemd_services = true;
      };

      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };
    };
  };
}
