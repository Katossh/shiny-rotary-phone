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
    };
  };

  # This workstation is an outbound SSH client, not an SSH server.
  services.openssh.enable = false;

  # VPN client configuration is part of the host's network stack.
  programs.amnezia-vpn.enable = true;
}
