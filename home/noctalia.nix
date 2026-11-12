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

  # One shared capsule per logical widget group. Palette roles provide
  # low-contrast fills that follow the active Catppuccin Frappé community palette.
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
      fill = "primary_container";
      foreground = "on_primary_container";
      border = "primary";
    };

    system = capsuleGroupStyle {
      fill = "secondary_container";
      foreground = "on_secondary_container";
      border = "secondary";
    };

    focus = capsuleGroupStyle {
      fill = "tertiary_container";
      foreground = "on_tertiary_container";
      border = "tertiary";
    };

    tools = capsuleGroupStyle {
      fill = "surface_container_low";
      foreground = "on_surface";
      border = "outline_variant";
    };

    media = capsuleGroupStyle {
      fill = "surface_container";
      foreground = "on_surface";
      border = "outline_variant";
    };

    connectivity = capsuleGroupStyle {
      fill = "surface_container_high";
      foreground = "on_surface";
      border = "outline_variant";
    };

    status = capsuleGroupStyle {
      fill = "surface_container_highest";
      foreground = "on_surface";
      border = "outline_variant";
    };
  };

  # The group controls each background and label colour; individual icons keep
  # distinct semantic accents so related widgets remain easy to scan.
  # Semantic palette roles follow the active Catppuccin Frappé Sapphire or Peach palette.
  widgetIconColors = {
    workspaces = "primary";
    wallpaper = "tertiary";

    ram = "secondary";
    temp = "tertiary";
    cat = "tertiary";

    active_window = "on_surface_variant";
    weather = "secondary";
    clock = "primary";

    clipboard = "secondary";
    widget = "primary";
    caffeine = "tertiary";
    widget_2 = "secondary";

    volume = "secondary";
    media = "tertiary";
    audio_visualizer = "primary";

    network = "secondary";
    bluetooth = "primary";
    battery = "tertiary";
    brightness = "secondary";

    tray = "on_surface_variant";
    notifications = "error";
    "control-center" = "primary";
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
      capsule_fill = "surface_container";
      capsule_foreground = "on_surface";
      capsule_border = "outline_variant";
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
