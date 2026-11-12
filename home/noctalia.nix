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

  # One shared capsule per logical widget group. The subdued fills follow a
  # cool-to-warm Catppuccin Frappé spectrum without turning the bar into a rainbow.
  capsuleGroupStyle =
    {
      fill,
      foreground,
      border,
    }:
    {
      inherit fill foreground border;
      border_width = 1.0;
      radius = 16.0;
      padding = 8.0;
      opacity = 0.98;
      widget_spacing = 5;
    };

  capsuleGroupStyles = {
    workspaces = capsuleGroupStyle {
      fill = "#344A6B";
      foreground = "#E6F0FF";
      border = "#7897C2";
    };

    system = capsuleGroupStyle {
      fill = "#355B55";
      foreground = "#DDF2E9";
      border = "#72A99B";
    };

    focus = capsuleGroupStyle {
      fill = "#3D506D";
      foreground = "#E7EEFF";
      border = "#7F9CC5";
    };

    tools = capsuleGroupStyle {
      fill = "#514B3A";
      foreground = "#F6EEDB";
      border = "#A99567";
    };

    media = capsuleGroupStyle {
      fill = "#574568";
      foreground = "#F0E6F6";
      border = "#9A82B3";
    };

    connectivity = capsuleGroupStyle {
      fill = "#3E5D6D";
      foreground = "#E0EFF4";
      border = "#7FA5B6";
    };

    status = capsuleGroupStyle {
      fill = "#4D4D70";
      foreground = "#ECEBFA";
      border = "#9290C2";
    };
  };

  # The group controls each background and label colour; individual icons keep
  # distinct semantic accents so related widgets remain easy to scan.
  widgetIconColors = {
    workspaces = "#8CAAEE";
    wallpaper = "#BABBF1";

    ram = "#A6D189";
    temp = "#EF9F76";
    cat = "#F4B8E4";

    active_window = "#C6D0F5";
    weather = "#99D1DB";
    clock = "#C6D0F5";

    clipboard = "#85C1DC";
    widget = "#E5C890";
    caffeine = "#A6D189";
    widget_2 = "#CA9EE6";

    volume = "#85C1DC";
    media = "#CA9EE6";
    audio_visualizer = "#81C8BE";

    network = "#99D1DB";
    bluetooth = "#8CAAEE";
    battery = "#A6D189";
    brightness = "#E5C890";

    tray = "#BABBF1";
    notifications = "#EF9F76";
    "control-center" = "#85C1DC";
  };

  # Keep this layout on a dedicated bar name. Noctalia applies GUI-managed state
  # overrides after declarative config, so stale bar.default group overrides must
  # not be allowed to shadow the seven groups defined in settings.toml.
  styledCapsuleGroups = map (
    group: group // (capsuleGroupStyles.${group.id} or { })
  ) exportedSettings.bar.main.capsule_group;

  styledWidgets = lib.mapAttrs (_name: iconColor: {
    icon_color = iconColor;
  }) widgetIconColors;

  settings = lib.recursiveUpdate exportedSettings {
    bar.main = {
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

      capsule_group = styledCapsuleGroups;
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
