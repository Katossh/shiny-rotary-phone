{ config, lib, ... }:

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

    desktop = {
      monitors = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              mode = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "3440x1440@179.982";
                description = ''
                  Optional Niri mode string. When omitted, Niri chooses the
                  preferred mode reported by the display.
                '';
              };

              scale = mkOption {
                type = types.nullOr (types.addCheck types.number (value: value > 0 && value <= 4));
                default = null;
                example = 1.25;
                description = ''
                  Optional logical scale factor greater than 0 and no greater
                  than 4.
                '';
              };

              position = mkOption {
                type = types.nullOr (
                  types.submodule {
                    options = {
                      x = mkOption {
                        type = types.int;
                        description = "Horizontal logical position.";
                      };
                      y = mkOption {
                        type = types.int;
                        description = "Vertical logical position.";
                      };
                    };
                  }
                );
                default = null;
                example = {
                  x = 3440;
                  y = 0;
                };
                description = ''
                  Optional logical output position. When omitted, Niri chooses
                  the output placement automatically.
                '';
              };
            };
          }
        );
        default = { };
        example = {
          "DP-1" = {
            mode = "3440x1440";
          };
          "HDMI-A-1" = {
            mode = "1920x1080@60.000";
            scale = 1.0;
            position = {
              x = 3440;
              y = 0;
            };
          };
        };
        description = ''
          Per-output Niri settings keyed by the connector reported by
          "niri msg outputs".
        '';
      };

      niri = {
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
  };

  assertions = lib.mapAttrsToList (outputName: output: {
    assertion = output.mode != null || output.scale != null || output.position != null;
    message = ''
      Starforge output "${outputName}" must set at least one of mode,
      scale, or position.
    '';
  }) config.starforge.user.desktop.monitors;
}
