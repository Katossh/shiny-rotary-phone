{
  pkgs,
  starforgeUsername,
  ...
}:

{
  imports = [
    ./preferences.nix
    ./deepcool-digital.nix
    ./gtk.nix
    ./niri.nix
    ./niri-layout-presets.nix
    ./noctalia.nix
    ./terminal-dotfiles.nix
    ./containers.nix
  ];

  home = {
    username = starforgeUsername;
    homeDirectory = "/home/${starforgeUsername}";
    stateVersion = "26.05";

    packages = with pkgs; [
      brightnessctl
      discord
      grim
      hyprpicker
      playerctl
      pavucontrol
      slurp
      tor-browser
      v2rayn
      xray
      localsend
      kalker
      wl-clipboard

      # Copy the declarative Russia-direct routing rules to the Wayland
      # clipboard for import through v2rayN's Routing Settings UI.
      (writeShellScriptBin "v2rayn-ru-routing" ''
        set -euo pipefail

        rules_file="'''${XDG_CONFIG_HOME:-$HOME/.config}/v2rayN/routing-ru.json"
        if [[ ! -r "$rules_file" ]]; then
          printf 'v2rayn-ru-routing: rules file not found: %s\n' "$rules_file" >&2
          exit 1
        fi

        if [[ -z "'''${WAYLAND_DISPLAY:-}" ]]; then
          printf '%s\n' "v2rayn-ru-routing: run this command inside the Wayland session." >&2
          exit 1
        fi

        ${wl-clipboard}/bin/wl-copy < "$rules_file"
        printf '%s\n' "Copied Russia-direct routing rules. Import them in v2rayN → Routing Settings."
      '')
    ];

    file = {
      "Pictures/Screenshots/.keep".text = "";

      # Keep the v2rayN Xray core and routing databases declaratively managed.
      ".local/share/v2rayN/bin/xray/xray" = {
        source = "${pkgs.xray}/bin/xray";
        force = true;
      };
      ".local/share/v2rayN/bin/geoip.dat" = {
        source = "${pkgs.v2ray-rules-dat}/share/v2ray/geoip.dat";
        force = true;
      };
      ".local/share/v2rayN/bin/geosite.dat" = {
        source = "${pkgs.v2ray-rules-dat}/share/v2ray/geosite.dat";
        force = true;
      };

      # v2rayN stores active routing profiles in its own database. This
      # declarative JSON is the import source, not a replacement for that DB.
      ".config/v2rayN/routing-ru.json".source = ./v2rayn/routing-ru.json;
    };

  };

  programs = {
    yazi = {
      enable = true;
      enableZshIntegration = true;
    };

    gh.enable = true;

    # Use Nixpkgs' rust-analyzer wrapper, which supplies the matching Rust
    # standard-library sources through RUST_SRC_PATH. Zed otherwise may download
    # its own server binary, which does not know about Nix's separate rust-src.
    zed-editor = {
      enable = true;
      package = null; # Zed itself is installed system-wide by the NixOS module.
      userSettings.lsp."rust-analyzer".binary.path = "${pkgs.rust-analyzer}/bin/rust-analyzer";
    };
  };

  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
        # Web pages and URL schemes.
        "text/html" = [ "firefox.desktop" ];
        "application/xhtml+xml" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "x-scheme-handler/about" = [ "firefox.desktop" ];
        "x-scheme-handler/unknown" = [ "firefox.desktop" ];

        # File manager.
        "inode/directory" = [ "org.kde.dolphin.desktop" ];
        "application/x-gnome-saved-search" = [ "org.kde.dolphin.desktop" ];
      };
    };
  };
}
