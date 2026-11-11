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

  # Noctalia capsule fills are ColorSpec values, not CSS backgrounds.
  # Distinct neighbouring fills create a coordinated, muted colour sweep.
  capsuleStyle =
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
      opacity = 0.97;
      widget_spacing = 7;
    };

  # Sapphire Islands: shared geometry, distinct Catppuccin Frappé hues.
  # Group IDs and membership remain sourced from settings.toml.
  capsuleGroupStyles = {
    navigation = capsuleStyle {
      fill = "#344A6B";
      foreground = "#DEE9FC";
      border = "#6E8CB8";
    };

    metrics = capsuleStyle {
      fill = "#36514D";
      foreground = "#DDF0E9";
      border = "#68958A";
    };

    time = capsuleStyle {
      fill = "#3A4F64";
      foreground = "#E0EDF5";
      border = "#6F93A7";
    };

    tools = capsuleStyle {
      fill = "#51425F";
      foreground = "#EDE3F5";
      border = "#8E77A9";
    };

    audio = capsuleStyle {
      fill = "#574152";
      foreground = "#F3E0EE";
      border = "#9C708F";
    };

    connectivity = capsuleStyle {
      fill = "#405247";
      foreground = "#E3F0DF";
      border = "#789A7A";
    };

    notifications = capsuleStyle {
      fill = "#59473D";
      foreground = "#F5E5D9";
      border = "#AA816C";
    };

    controls = capsuleStyle {
      fill = "#46445F";
      foreground = "#E9E5F7";
      border = "#827BAA";
    };
  };

  # Icons use individual Catppuccin accents; labels inherit their group's
  # softer foreground so the capsules remain readable and visually unified.
  widgetIconColors = {
    launcher = "#85C1DC";
    workspaces = "#8CAAEE";
    wallpaper = "#BABBF1";
    ram = "#A6D189";
    temp = "#EF9F76";
    cat = "#F4B8E4";
    weather = "#99D1DB";
    clock = "#C6D0F5";
    widget = "#E5C890";
    caffeine = "#A6D189";
    widget_2 = "#CA9EE6";
    volume = "#85C1DC";
    media = "#CA9EE6";
    audio_visualizer = "#81C8BE";
    network = "#99D1DB";
    bluetooth = "#8CAAEE";
    battery = "#A6D189";
    tray = "#BABBF1";
    notifications = "#EF9F76";
    privacy = "#E5C890";
    "control-center" = "#85C1DC";
    session = "#CA9EE6";
  };

  styledCapsuleGroups = map (
    group: group // (capsuleGroupStyles.${group.id} or { })
  ) exportedSettings.bar.default.capsule_group;

  settings = lib.recursiveUpdate exportedSettings {
    bar.default = {
      # A transparent canvas lets the independently tinted capsules float.
      background_opacity = 0.0;
      compositor_blur = false;

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

    widget = lib.mapAttrs (_name: iconColor: {
      icon_color = iconColor;
    }) widgetIconColors;

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
