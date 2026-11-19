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
        tag = finalAttrs.version;
        hash = "sha256-CC0pxktunkfCjP53ArftEn6h0Wsw/oWJrGjEpXcxjqM=";
        fetchSubmodules = true;
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
        export DEV_AGW_PUBLIC_KEY="''${DEV_AGW_PUBLIC_KEY%\\n}"
        export PROD_AGW_PUBLIC_KEY="''${PROD_AGW_PUBLIC_KEY%\\n}"
      '';
    }
  );
in
{
  networking = {
    networkmanager.enable = true;

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
