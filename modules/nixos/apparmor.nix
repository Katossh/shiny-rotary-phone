{ config, pkgs, ... }:

let
  browserCredentialDenials = ''
    # Browsers should not need direct access to local developer credentials.
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

  browserProfile =
    executable: configPath: cachePath: ''
      abi <abi/4.0>,
      include <tunables/global>

      profile ${executable} {
        include <abstractions/base>
        include <abstractions/nameservice>
        include <abstractions/ssl_certs>
        include <abstractions/user-tmp>

        # Runtime files and shared libraries are immutable Nix store content.
        /nix/store/** mr,

        # Keep browser state and explicit downloads writable.
        owner @{HOME}/${configPath}/** rwk,
        owner @{HOME}/${cachePath}/** rwk,
        owner @{HOME}/Downloads/** rwk,

        # Browsers need ordinary client networking.
        network inet stream,
        network inet dgram,
        network inet6 stream,
        network inet6 dgram,

        ${browserCredentialDenials}
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

      # Runtime files and shared libraries are immutable Nix store content.
      /nix/store/** mr,

      # Editors and extensions need outbound networking and may launch tools.
      # These profiles stay in complain mode while their process trees are audited.
      network inet stream,
      network inet dgram,
      network inet6 stream,
      network inet6 dgram,
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
        # Keep the existing, deliberately enforced curl profile.
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

            # curl needs its executable and shared libraries from the immutable
            # Nix store, but must not modify the store.
            /nix/store/** mr,

            # Support ordinary uploads, downloads, and config files in the
            # invoking user's home directory.
            owner @{HOME}/ rw,
            owner @{HOME}/** rwk,

            # Do not let a compromised curl process read or overwrite private
            # SSH/GPG key material or common cloud/CLI credential stores.
            deny owner @{HOME}/.ssh/** rw,
            deny owner @{HOME}/.gnupg/** rw,
            deny owner @{HOME}/.aws/** rw,
            deny owner @{HOME}/.config/gh/** rw,
            deny owner @{HOME}/.config/gcloud/** rw,

            # HTTP(S), DNS, and other ordinary TCP/UDP client traffic.
            network inet stream,
            network inet dgram,
            network inet6 stream,
            network inet6 dgram,
          }
        '';
      };

      # Complain mode is intentionally a staging phase: unlisted operations are
      # logged but allowed. Explicit deny rules below remain enforced.
      firefox = {
        state = "complain";
        profile = browserProfile
          "${config.programs.firefox.finalPackage}/bin/firefox"
          ".mozilla"
          ".cache/mozilla";
      };

      chromium = {
        state = "complain";
        profile = browserProfile
          "${pkgs.chromium.browser}/libexec/chromium/chromium"
          ".config/chromium"
          ".cache/chromium";
      };

      # IDEs run user code, build scripts, language servers, terminals and plugins.
      # Keep them in complain mode without hard-coded credential denies until
      # their actual workflows and child-process trees have been reviewed.
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
