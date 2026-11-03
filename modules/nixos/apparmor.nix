{ pkgs, ... }:

{
  security.apparmor = {
    enable = true;

    # Keep activation changes non-disruptive for already-running desktop apps.
    killUnconfinedConfinables = false;

    policies.curl = {
      # Enforce filesystem and network boundaries for the system curl binary.
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
  };

  environment.systemPackages = [ pkgs.curl ];
}
