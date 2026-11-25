{ pkgs, ... }:

let
  libagw = pkgs.callPackage ./packages/libagw.nix { };

  # The locked Nixpkgs revision still ships 5.0.3.0. AmneziaVPN 5.1.0.6
  # additionally needs libagw and Qt HttpServer, so this is a source override,
  # not just a version-string change.
  amneziaVpn = pkgs.amnezia-vpn.overrideAttrs (
    finalAttrs: previousAttrs: {
      version = "5.1.0.6";

      src = pkgs.fetchFromGitHub {
        owner = "amnezia-vpn";
        repo = "amnezia-client";
        # Pin the verified 5.1.0.6 tag commit; the previous hash did not match
        # the recursively fetched source tree (including its submodules).
        rev = "ac175c8a8147cfe56f98c8372ec17ea2ba00bb02";
        hash = "sha256-o09F55FjmlBXtFTWwWmAOsea+56QlJiA4DuRFuBVtRI=";
        fetchSubmodules = true;

        # Preserve the metadata consumed by the inherited preConfigure hook.
        postCheckout = ''
          git -C "$out" rev-parse --short HEAD > "$out/.git-revision"
          git -C "$out" show -s --format=%ct HEAD > "$out/.source-date-epoch"
        '';
      };

      postPatch = (previousAttrs.postPatch or "") + ''
        substituteInPlace client/CMakeLists.txt \
          --replace-fail 'find_package(libagw REQUIRED)' 'add_library(amnezia::libagw STATIC IMPORTED)
        set_target_properties(amnezia::libagw PROPERTIES
          IMPORTED_LOCATION "${libagw}/lib/libagw.a"
          INTERFACE_INCLUDE_DIRECTORIES "${libagw}/include")'
      '';

      buildInputs = previousAttrs.buildInputs ++ [
        pkgs.kdePackages.qthttpserver
      ];

      # The bundled AGW PEM files contain a final newline that changes the
      # derived decryption key. Match the bytes embedded by the upstream build.
      preConfigure = (previousAttrs.preConfigure or "") + ''
        # The upstream 5.1.0.6 tag commit is 2026-11-02T16:23:52Z.
        # Use its verified Unix timestamp instead of reading the malformed
        # .source-date-epoch emitted by the overridden source fetcher.
        export SOURCE_DATE_EPOCH=1793636632

        export DEV_AGW_PUBLIC_KEY="''${DEV_AGW_PUBLIC_KEY%\\n}"
        export PROD_AGW_PUBLIC_KEY="''${PROD_AGW_PUBLIC_KEY%\\n}"
      '';
    }
  );
in
{
  # v2rayN's TUN mode needs the kernel TUN device. The GUI remains an
  # unprivileged user process; v2rayN elevates only the selected core when
  # creating the tunnel and changing routes.
  boot.kernelModules = [ "tun" ];

  networking = {
    networkmanager = {
      enable = true;

      # Disable Wi-Fi power saving for more consistent responsiveness.
      # The trade-off is slightly higher power consumption while Wi-Fi is on.
      wifi.powersave = false;
    };

    # Network exposure policy belongs with network configuration. Keep the
    # default iptables backend for compatibility with libvirt networking.
    # Host-specific interface and subnet exceptions live in the host profile.
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };
  };

  # This workstation is an outbound SSH client, not an SSH server.
  services.openssh.enable = false;

  # VPN client configuration is part of the host's network stack.
  programs.amnezia-vpn = {
    enable = true;
    package = amneziaVpn;
  };
}
