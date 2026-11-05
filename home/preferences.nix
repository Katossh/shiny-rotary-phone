{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.starforge.user = {
    appearance = {
      themeMode = mkOption {
        type = types.enum [
          "dark"
          "light"
          "auto"
        ];
        default = "dark";
        description = ''
          Noctalia color-scheme mode. "auto" follows Noctalia's configured
          sunrise/sunset schedule; it does not configure the schedule itself.
        '';
      };

      palette = mkOption {
        type = types.enum [
          "Ayu"
          "Catppuccin"
          "Dracula"
          "Eldritch"
          "Gruvbox"
          "Kanagawa"
          "Noctalia"
          "Nord"
          "Rosé Pine"
          "Tokyo-Night"
        ];
        default = "Catppuccin";
        description = ''
          Built-in Noctalia palette. This option applies only while the
          palette source is the built-in palette collection.
        '';
      };

      fontFamily = mkOption {
        type = types.str;
        default = "Inter";
        example = "Inter";
        description = ''
          Primary Noctalia UI font family. The named font must be available
          through Fontconfig; this option does not install font packages.
        '';
      };
    };

    desktop.niri = {
      keyboardLayout = mkOption {
        type = types.str;
        default = "us,ru";
        example = "us,gb";
        description = ''
          Comma-separated XKB keyboard layout identifiers passed to Niri.
        '';
      };

      keyboardLayoutOptions = mkOption {
        type = types.str;
        default = "grp:alt_shift_toggle";
        example = "grp:win_space_toggle";
        description = ''
          XKB keyboard layout options passed to Niri.
        '';
      };

      gaps = mkOption {
        type = types.ints.between 0 64;
        default = 12;
        example = 8;
        description = ''
          Niri layout gap in logical pixels. Accepted range: 0 through 64.
        '';
      };
    };
  };
}
