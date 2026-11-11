{
  config,
  inputs,
  lib,
  ...
}:

let
  exportedSettings = builtins.fromTOML (builtins.readFile ./noctalia/settings.toml);

  picturesDirectory =
    if config.xdg.userDirs.pictures == null then
      "${config.home.homeDirectory}/Pictures"
    else
      config.xdg.userDirs.pictures;

  wallpaperDirectory = "${picturesDirectory}/Wallpapers";

  favoriteWallpapers = map (
    wallpaper:
    wallpaper
    // {
      path = "${wallpaperDirectory}/${wallpaper.path}";
    }
  ) exportedSettings.wallpaper.favorite;

  # Noctalia supports fixed ColorSpec values for each widget capsule.
  # One pill per widget makes the hue and foreground explicit and avoids
  # relying on capsule-group expansion for core bar visibility.
  capsuleStyle =
    {
      fill,
      foreground,
      border,
      icon,
    }:
    {
      capsule = true;
      capsule_fill = fill;
      capsule_foreground = foreground;
      capsule_border = border;
      capsule_border_width = 1.0;
      capsule_radius = 16.0;
      capsule_padding = 8.0;
      capsule_opacity = 0.98;
      icon_color = icon;
    };

  # Coordinated Catppuccin Frappé spectrum: dark, saturated capsule fills
  # with readable foregrounds and a matching individual icon accent.
  widgetCapsuleStyles = {
    launcher = {
      fill = "#344A6B";
      foreground = "#E6F0FF";
      border = "#7897C2";
      icon = "#85C1DC";
    };
    workspaces = {
      fill = "#3B5680";
      foreground = "#E5EDFF";
      border = "#819FD0";
      icon = "#8CAAEE";
    };
    wallpaper = {
      fill = "#4A4C78";
      foreground = "#ECEBFF";
      border = "#918FC7";
      icon = "#BABBF1";
    };
    keyboard_layout = {
      fill = "#53486F";
      foreground = "#F1E9FC";
      border = "#9D87C1";
      icon = "#CA9EE6";
    };
    active_window = {
      fill = "#425065";
      foreground = "#E8EDF5";
      border = "#8297B4";
      icon = "#C6D0F5";
    };

    ram = {
      fill = "#355B55";
      foreground = "#DDF2E9";
      border = "#72A99B";
      icon = "#A6D189";
    };
    temp = {
      fill = "#66483D";
      foreground = "#F8E6DC";
      border = "#B4826D";
      icon = "#EF9F76";
    };
    cat = {
      fill = "#654B65";
      foreground = "#F5E7F3";
      border = "#AB84A8";
      icon = "#F4B8E4";
    };
    weather = {
      fill = "#355C66";
      foreground = "#DFF1F4";
      border = "#73A9B4";
      icon = "#99D1DB";
    };
    clock = {
      fill = "#3D506D";
      foreground = "#E7EEFF";
      border = "#7F9CC5";
      icon = "#C6D0F5";
    };

    clipboard = {
      fill = "#3C586B";
      foreground = "#E0EDF5";
      border = "#729EB3";
      icon = "#85C1DC";
    };
    widget = {
      fill = "#625338";
      foreground = "#F6EEDB";
      border = "#B29B68";
      icon = "#E5C890";
    };
    caffeine = {
      fill = "#405A49";
      foreground = "#E2F1E3";
      border = "#7EA888";
      icon = "#A6D189";
    };
    widget_2 = {
      fill = "#5A4869";
      foreground = "#F1E7FA";
      border = "#9E82BA";
      icon = "#CA9EE6";
    };

    volume = {
      fill = "#36566F";
      foreground = "#E1EFF8";
      border = "#77A6C3";
      icon = "#85C1DC";
    };
    media = {
      fill = "#574568";
      foreground = "#F0E6F6";
      border = "#9A82B3";
      icon = "#CA9EE6";
    };
    audio_visualizer = {
      fill = "#31584F";
      foreground = "#DDF2E9";
      border = "#6DA798";
      icon = "#81C8BE";
    };

    network = {
      fill = "#3E5D6D";
      foreground = "#E0EFF4";
      border = "#7FA5B6";
      icon = "#99D1DB";
    };
    bluetooth = {
      fill = "#435779";
      foreground = "#E6EDFC";
      border = "#829CC8";
      icon = "#8CAAEE";
    };
    battery = {
      fill = "#425D49";
      foreground = "#E4F2E1";
      border = "#82A987";
      icon = "#A6D189";
    };
    brightness = {
      fill = "#66533A";
      foreground = "#F7EEDC";
      border = "#B59A68";
      icon = "#E5C890";
    };

    tray = {
      fill = "#4D4D70";
      foreground = "#ECEBFA";
      border = "#9290C2";
      icon = "#BABBF1";
    };
    notifications = {
      fill = "#694B3F";
      foreground = "#F8E6DC";
      border = "#B78670";
      icon = "#EF9F76";
    };
    privacy = {
      fill = "#645A39";
      foreground = "#F5EEDB";
      border = "#B0A06A";
      icon = "#E5C890";
    };
    "control-center" = {
      fill = "#3C596B";
      foreground = "#E1EEF5";
      border = "#79A0B4";
      icon = "#85C1DC";
    };
    session = {
      fill = "#584667";
      foreground = "#F0E7F6";
      border = "#9C81B1";
      icon = "#CA9EE6";
    };
  };

  styledWidgets = lib.mapAttrs (_name: capsuleStyle) widgetCapsuleStyles;

  settings = lib.recursiveUpdate exportedSettings {
    bar.default = {
      background_opacity = 0.0;
      compositor_blur = false;

      font_family = config.starforge.user.appearance.fontFamily;
      font_weight = 600;
      font_scale = 1.04;

      capsule = true;
      capsule_fill = "#38445B";
      capsule_foreground = "#E8EAF2";
      capsule_border = "#7386A5";
      capsule_thickness = 0.86;
      capsule_radius = 16.0;
      capsule_padding = 8.0;
      capsule_opacity = 0.98;
      capsule_border_width = 1.0;
      widget_spacing = 6;
      hover_highlight = true;
    };

    widget = styledWidgets;

    shell.font_family = config.starforge.user.appearance.fontFamily;

    theme = {
      mode = config.starforge.user.appearance.themeMode;
      source = config.starforge.user.appearance.paletteSource;
      builtin = config.starforge.user.appearance.palette;
      community_palette = config.starforge.user.appearance.communityPalette;
    };

    plugin_settings."noctalia/wallhaven".download_dir = wallpaperDirectory;

    wallpaper = {
      directory = wallpaperDirectory;
      default.path = "${wallpaperDirectory}/${exportedSettings.wallpaper.default.path}";
      last.path = "${wallpaperDirectory}/${exportedSettings.wallpaper.last.path}";
      favorite = favoriteWallpapers;
    };
  };
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    checkConfig = true;
    inherit settings;
  };
}
