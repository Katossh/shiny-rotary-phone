_:

{
  networking = {
    networkmanager.enable = true;

    # Network exposure policy belongs with network configuration. Keep the
    # default iptables backend for compatibility with libvirt networking.
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];

      # Expose the llama.cpp API only to IPv4 clients on the home Wi-Fi LAN.
      # Match both ingress interface and source subnet: an interface-only
      # allowance would also accept non-LAN sources arriving on this NIC.
      extraCommands = ''
        iptables -A nixos-fw \
          -i wlp7s0 \
          -s 192.168.0.0/24 \
          -p tcp --dport 1234 \
          -j nixos-fw-accept
      '';
    };
  };

  # This workstation is an outbound SSH client, not an SSH server.
  services.openssh.enable = false;

  # VPN client configuration is part of the host's network stack.
  programs.amnezia-vpn.enable = true;
}
