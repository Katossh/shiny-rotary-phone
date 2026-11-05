{ config, lib, pkgs, ... }:

let
  credentialDenials = ''
    # Desktop applications do not need direct access to local developer credentials.
    deny owner @{HOME}/.ssh/** rw,
    deny owner @{HOME}/.gnupg/** rw,
    deny owner @{HOME}/.aws/** rw,
    deny owner @{HOME}/.config/gh/** rw,
    deny owner @{HOME}/.config/gcloud/** rw,
    deny owner @{HOME}/.kube/** rw,
    deny owner @{HOME}/.docker/config.json rw,
    deny owner @{HOME}/.config/sops/age/keys.txt rw,
    deny owner @{HOME}/.password-store/** rw,
  '';

  networkClientRules = ''
    network inet stream,
    network inet dgram,
    network inet6 stream,
    network inet6 dgram,
  '';

  desktopRuntimeRules = ''
    # User-session IPC and Wayland/Xwayland display sockets.
    owner /run/user/[0-9]*/bus rw,
    owner /run/user/[0-9]*/wayland-* rw,
    owner /run/user/[0-9]*/at-spi/bus_0 rw,
    owner /run/user/[0-9]*/doc/** rwk,
    owner /run/user/[0-9]*/pipewire-0 rw,
    owner /run/user/[0-9]*/pulse/native rw,
    owner @{HOME}/.Xauthority r,
    owner /tmp/.X11-unix/X* rw,

    # GPU, shared memory and audio device access remains subject to Unix DAC.
    /dev/dri/renderD* rw,
    /dev/shm/** rwk,
    /dev/snd/** rw,
  '';

  # Initial GUI profiles deliberately use complain mode. These allow rules
  # document the intended runtime surface while audit logs reveal additional
  # paths required by this specific NixOS desktop.
  guiClientProfile = executable: appDataRules: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/nameservice>
      include <abstractions/ssl_certs>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      ${appDataRules}
      ${desktopRuntimeRules}
      ${networkClientRules}
      ${credentialDenials}
    }
  '';

  browserProfile = executable: configPath: cachePath: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/nameservice>
      include <abstractions/ssl_certs>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      owner @{HOME}/${configPath}/** rwk,
      owner @{HOME}/${cachePath}/** rwk,
      owner @{HOME}/Downloads/** rwk,

      ${networkClientRules}
      ${credentialDenials}
    }
  '';

  mediaPlayerProfile = executable: mediaRules: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/nameservice>
      include <abstractions/ssl_certs>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      ${mediaRules}
      ${desktopRuntimeRules}
      ${networkClientRules}
      ${credentialDenials}
    }
  '';

  downloaderProfile = executable: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/nameservice>
      include <abstractions/ssl_certs>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      # yt-dlp writes only to the normal media/download locations by default.
      owner @{HOME}/Downloads/** rwk,
      owner @{HOME}/Videos/** rwk,
      owner @{HOME}/Music/** rwk,
      owner @{HOME}/.config/yt-dlp/** r,
      owner @{HOME}/.cache/yt-dlp/** rwk,
      owner @{HOME}/.local/share/yt-dlp/** rwk,

      # Permit the Nixpkgs-provided media post-processor and JS runtime.
      ${lib.getExe pkgs.ffmpeg-headless} ix,
      ${lib.getExe pkgs.deno} ix,

      # Do not let a downloader silently harvest browser session cookies.
      deny owner @{HOME}/.mozilla/**/cookies.sqlite r,
      deny owner @{HOME}/.config/chromium/**/Cookies r,
      deny owner @{HOME}/.config/google-chrome/**/Cookies r,
      deny owner @{HOME}/.config/BraveSoftware/**/Cookies r,
      deny owner @{HOME}/.config/microsoft-edge/**/Cookies r,

      ${networkClientRules}
      ${credentialDenials}
    }
  '';

  editorProfile = executable: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/nameservice>
      include <abstractions/ssl_certs>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      # Editors and extensions run user code, language servers and terminals.
      # Keep these profiles in complain mode until their child-process trees
      # have been reviewed on the actual workstation.
      ${networkClientRules}
    }
  '';
in
{
  security.apparmor = {
    enable = true;

    # Keep activation changes non-disruptive for already-running desktop apps.
    killUnconfinedConfinables = false;

    policies = {
      curl = {
        state = "enforce";
        profile = ''
          abi <abi/4.0>,
          include <tunables/global>

          profile ${pkgs.curl}/bin/curl {
            include <abstractions/base>
            include <abstractions/consoles>
            include <abstractions/nameservice>
            include <abstractions/ssl_certs>
            include <abstractions/user-tmp>

            /nix/store/** mr,

            # curl supports ordinary file uploads and downloads, but must not
            # access local credentials even when given an attacker-controlled URL.
            owner @{HOME}/ rw,
            owner @{HOME}/** rwk,
            deny owner @{HOME}/.ssh/** rw,
            deny owner @{HOME}/.gnupg/** rw,
            deny owner @{HOME}/.aws/** rw,
            deny owner @{HOME}/.config/gh/** rw,
            deny owner @{HOME}/.config/gcloud/** rw,

            ${networkClientRules}
          }
        '';
      };

      firefox = {
        state = "complain";
        profile =
          browserProfile "${config.programs.firefox.finalPackage}/bin/firefox" ".mozilla"
            ".cache/mozilla";
      };

      chromium = {
        state = "complain";
        profile =
          browserProfile "${pkgs.chromium.browser}/libexec/chromium/chromium" ".config/chromium"
            ".cache/chromium";
      };

      localsend = {
        state = "complain";
        profile = guiClientProfile (lib.getExe pkgs.localsend) ''
          owner @{HOME}/.config/localsend/** rwk,
          owner @{HOME}/.config/org.localsend.localsend_app/** rwk,
          owner @{HOME}/.local/share/localsend/** rwk,
          owner @{HOME}/.local/share/org.localsend.localsend_app/** rwk,
          owner @{HOME}/.cache/localsend/** rwk,

          # File sharing needs downloads and portal-granted document access.
          owner @{HOME}/Downloads/** rwk,
          owner @{HOME}/Documents/** r,
          owner @{HOME}/Pictures/** r,
          owner @{HOME}/Videos/** r,
          owner @{HOME}/Music/** r,
        '';
      };

      telegram = {
        state = "complain";
        profile = guiClientProfile (lib.getExe pkgs.telegram-desktop) ''
          owner @{HOME}/.local/share/TelegramDesktop/** rwk,
          owner @{HOME}/.config/TelegramDesktop/** rwk,
          owner @{HOME}/.cache/TelegramDesktop/** rwk,
          owner @{HOME}/Downloads/** rwk,
        '';
      };

      discord = {
        state = "complain";
        profile = guiClientProfile (lib.getExe pkgs.discord) ''
          owner @{HOME}/.config/discord/** rwk,
          owner @{HOME}/.cache/discord/** rwk,
          owner @{HOME}/.local/share/discord/** rwk,
          owner @{HOME}/Downloads/** rwk,
        '';
      };

      mpv = {
        state = "complain";
        profile = mediaPlayerProfile (lib.getExe pkgs.mpv) ''
          owner @{HOME}/.config/mpv/** rwk,
          owner @{HOME}/.cache/mpv/** rwk,
          owner @{HOME}/.local/share/mpv/** rwk,

          # Read media from the usual user directories; keep writes out of them.
          owner @{HOME}/Documents/** r,
          owner @{HOME}/Downloads/** r,
          owner @{HOME}/Music/** r,
          owner @{HOME}/Pictures/** r,
          owner @{HOME}/Videos/** r,

          /dev/dri/renderD* rw,
          /dev/snd/** rw,
        '';
      };

      yt-dlp = {
        state = "complain";
        profile = downloaderProfile (lib.getExe pkgs.yt-dlp);
      };

      vscode = {
        state = "complain";
        profile = editorProfile "${pkgs.vscode}/lib/vscode/code";
      };

      zed = {
        state = "complain";
        profile = editorProfile "${pkgs.zed-editor}/libexec/zed-editor";
      };
    };
  };

  environment.systemPackages = [ pkgs.curl ];
}
