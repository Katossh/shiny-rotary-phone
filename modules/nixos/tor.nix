{ pkgs, ... }:

{
  # Keep a local Tor SOCKS5 proxy available without starting Tor Browser.
  # WebTunnel is the only enabled pluggable transport; bridge lines are
  # maintained outside the Nix store in a root-managed local file.
  services.tor = {
    enable = true;

    client = {
      enable = true;
      socksListenAddress = {
        addr = "127.0.0.1";
        port = 9050;
        IsolateDestAddr = true;
      };
    };

    settings = {
      UseBridges = true;
      ClientTransportPlugin = "webtunnel exec ${pkgs.webtunnel}/bin/client";
      "%include" = "/etc/tor/bridges.conf";
    };
  };

  # Create the local bridge file without putting its contents in the Nix store.
  # It is readable by the tor service and editable only by root.
  systemd.tmpfiles.rules = [
    "d /etc/tor 0750 root tor -"
    "f /etc/tor/bridges.conf 0640 root tor -"
  ];
}
