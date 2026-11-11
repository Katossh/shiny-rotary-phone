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

  # Sapphire Islands: dark, individually tinted capsules with soft outlines.
  # Group IDs and membership remain sourced from settings.toml.
  capsuleGroupStyles = {
    g1 = {
      fill = "#40384F";
      foreground = "#E7DDF2";
      border = "#665579";
      border_width = 0.8;
      radius = 16.0;
      padding = 8.0;
      opacity = 0.97;
      widget_spacing = 7;
    };

    g2 = {
      fill = "#34475B";
      foreground = "#DDEAF5";
      border = "#526C84";
      border_width = 0.8;
      radius = 16.0;
      padding = 8.0;
      opacity = 0.97;
      widget_spacing = 7;
    };

    g3 = {
      fill = "#39465B";
      foreground = "#DFEAF5";
      border = "#536A87";
      border_width = 0.8;
      radius = 16.0;
      padding = 8.0;
      opacity = 0.97;
      widget_spacing = 7;
    };

    g4 = {
      fill = "#3E4058";
      foreground = "#E2E3F4";
      border = "#596180";
      border_width = 0.8;
      radius = 16.0;
      padding = 8.0;
      opacity = 0.97;
      widget_spacing = 7;
    };

    g5 = {
      fill = "#39445E";
      foreground = "#E1E8F5";
      border = "#546B8B";
      border_width = 0.8;
      radius = 16.0;
      padding = 8.0;
      opacity = 0.97;
      widget_spacing = 7;
    };

    g6 = {
      fill = "#354A61";
      foreground = "#E0EBF7";
      border = "#547491";
      border_width = 0.8;
      radius = 16.0;
      padding = 8.0;
      opacity = 0.97;
      widget_spacing = 7;
    };

    g7 = {
      fill = "#354A4D";
      foreground = "#DDEFE8";
      border = "#52736F";
      border_width = 0.8;
      radius = 16.0;
      padding = 8.0;
      opacity = 0.97;
      widget_spacing = 7;
    };

    g8 = {
      fill = "#414457";
      foreground = "#E4E5F1";
      border = "#5B617D";
      border_width = 0.8;
      radius = 16.0;
      padding = 8.0;
      opacity = 0.97;
      widget_spacing = 7;
    };
  };

  # Bright Catppuccin accents are reserved for glyphs; labels inherit each
  # capsule group's softer foreground for a calmer, more readable result.
  widgetIconColors = {
    launcher = "#85C1DC";
    workspaces = "#8CAAEE";
    wallpaper = "#BABBF1";
    ram = "#81C8BE";
    temp = "#EF9F76";
    cat = "#F4B8E4";
    network = "#85C1DC";
    bluetooth = "#8CAAEE";
    battery = "#A6D189";
    volume = "#85C1DC";
    media = "#CA9EE6";
    audio_visualizer = "#81C8BE";
    tray = "#B5BFE2";
    notifications = "#EF9F76";
    session = "#CA9EE6";
    weather = "#99D1DB";
    clock = "#C6D0F5";
    date = "#BABBF1";
    privacy = "#E5C890";
    "control-center" = "#85C1DC";
    widget = "#E5C890";
    widget_2 = "#CA9EE6";
    caffeine = "#A6D189";
  };

  styledCapsuleGroups = map (
    group:
    group // (capsuleGroupStyles.${group.id} or { })
  ) exportedSettings.bar.default.capsule_group;

  settings = lib.recursiveUpdate exportedSettings {
    bar.default = {
      # A transparent bar canvas lets the separate capsule groups read as
      # floating islands instead of one continuous panel.
      background_opacity = 0.0;
      compositor_blur = false;

      # Inter remains the configured typeface; slightly stronger labels make
      # the compact widgets legible without increasing their footprint.
      font_family = config.starforge.user.appearance.fontFamily;
      font_weight = 600;
      font_scale = 1.04;

      capsule = true;
      capsule_thickness = 0.84;
      capsule_radius = 16.0;
      capsule_padding = 8.0;
      capsule_opacity = 0.97;
      capsule_border_width = 0.8;
      widget_spacing = 7;
      hover_highlight = true;

      capsule_group = styledCapsuleGroups;
    };

    # Noctalia resolves icon_color separately from the label foreground.
    widget = lib.mapAttrs (
      _name: iconColor: {
        icon_color = iconColor;
      }
    ) widgetIconColors;

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
