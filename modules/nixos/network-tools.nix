{ lib, pkgs, ... }:

{
  # Native GNS3 desktop client and terminal backend for node consoles.
  environment.systemPackages = with pkgs; [
    gns3-gui
    inetutils
  ];

  # Keep the local GNS3 API off the LAN. The GUI detects and connects to this
  # managed server instead of starting an unmanaged second instance.
  services.gns3-server = {
    enable = true;

    dynamips.enable = true;
    ubridge.enable = true;
    vpcs.enable = true;

    settings.Server = {
      host = "127.0.0.1";
      port = 3080;
    };
  };

  # The upstream service module already grants /dev/kvm device access and
  # libvirt socket access. The kvm group is separately needed for the device
  # node's Unix permissions when QEMU runs as the unprivileged gns3 account.
  systemd.services.gns3-server.serviceConfig.SupplementaryGroups = lib.mkAfter [ "kvm" ];

  # Install the Qt application and delegate packet capture to dumpcap's
  # capability-limited wrapper rather than running Wireshark as root.
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
    dumpcap.enable = true;
    usbmon.enable = false;
  };
}
