{
  config,
  lib,
  pkgs,
  ...
}:

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

  jsonToolProfile = executable: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      # jq reads input files and writes transformed JSON to stdout.
      # Keep filesystem access read-only and protect local developer credentials.
      owner @{HOME}/** r,

      ${credentialDenials}
    }
  '';

  mediaProcessorProfile = executable: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/nameservice>
      include <abstractions/ssl_certs>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      owner @{HOME}/.config/ffmpeg/** r,
      owner @{HOME}/.cache/ffmpeg/** rwk,

      # Read source media and write converted files in normal media locations.
      owner @{HOME}/Documents/** r,
      owner @{HOME}/Downloads/** rwk,
      owner @{HOME}/Music/** rwk,
      owner @{HOME}/Pictures/** rwk,
      owner @{HOME}/Videos/** rwk,

      # Optional VA-API/Vulkan-capable hardware paths; Unix DAC still applies.
      /dev/dri/renderD* rw,

      ${networkClientRules}
      ${credentialDenials}
    }
  '';

  systemMonitorProfile = executable: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      # btop reads process, CPU, memory, network and hardware telemetry.
      /proc/** r,
      /sys/class/hwmon/** r,
      /sys/class/thermal/** r,
      /sys/class/drm/** r,
      /sys/devices/system/cpu/** r,
      /sys/devices/system/node/** r,
      /sys/devices/virtual/** r,
      /dev/dri/** r,

      owner @{HOME}/.config/btop/** rwk,
      owner @{HOME}/.cache/btop/** rwk,

      ${credentialDenials}
    }
  '';

  systemInfoProfile = executable: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>

      /nix/store/** mr,

      # fastfetch collects system information from procfs/sysfs and OS metadata.
      /proc/** r,
      /sys/** r,
      /etc/os-release r,
      /etc/hostname r,
      /etc/lsb-release r,
      /dev/dri/** r,

      owner @{HOME}/.config/fastfetch/** r,

      ${credentialDenials}
    }
  '';

  audioControlProfile = executable: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      owner @{HOME}/.config/pavucontrol.ini rwk,
      owner @{HOME}/.config/pulse/** r,

      ${desktopRuntimeRules}
      ${credentialDenials}
    }
  '';

  virtualMachineManagerProfile = executable: ''
    abi <abi/4.0>,
    include <tunables/global>

    profile ${executable} {
      include <abstractions/base>
      include <abstractions/ssl_certs>
      include <abstractions/user-tmp>

      /nix/store/** mr,

      owner @{HOME}/.config/virt-manager/** rwk,
      owner @{HOME}/.cache/virt-manager/** rwk,
      owner @{HOME}/.local/share/virt-manager/** rwk,
      owner @{HOME}/Downloads/** r,
      owner @{HOME}/Documents/** r,

      # This host manages local QEMU/KVM through libvirt's system socket.
      /run/libvirt/libvirt-sock rw,
      /run/libvirt/libvirt-sock-ro r,

      ${desktopRuntimeRules}
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

      ffmpeg = {
        state = "complain";
        profile = mediaProcessorProfile (lib.getExe pkgs.ffmpeg-headless);
      };

      jq = {
        state = "complain";
        profile = jsonToolProfile (lib.getExe pkgs.jq);
      };

      btop = {
        state = "complain";
        profile = systemMonitorProfile (lib.getExe pkgs.btop);
      };

      fastfetch = {
        state = "complain";
        profile = systemInfoProfile (lib.getExe pkgs.fastfetch);
      };

      pavucontrol = {
        state = "complain";
        profile = audioControlProfile (lib.getExe pkgs.pavucontrol);
      };

      virt-manager = {
        state = "complain";
        profile = virtualMachineManagerProfile (lib.getExe pkgs.virt-manager);
      };

      vscode = {
        state = "complain";
        profile = editorProfile "${pkgs.vscode}/lib/vscode/code";
      };

      neovim = {
        state = "complain";
        profile = editorProfile (lib.getExe pkgs.neovim);
      };

      zed = {
        state = "complain";
        profile = editorProfile "${pkgs.zed-editor}/libexec/zed-editor";
      };
    };
  };

  environment.systemPackages = [ pkgs.curl ];
}
