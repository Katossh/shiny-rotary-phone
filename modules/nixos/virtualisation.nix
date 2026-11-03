{ config, pkgs, ... }:

let
  virsh = "${config.virtualisation.libvirtd.package}/bin/virsh";
in
{
  # KVM/QEMU managed through libvirt. QEMU guests run as the dedicated
  # unprivileged qemu-libvirtd account rather than as root.
  virtualisation.libvirtd = {
    enable = true;

    # Ask guests to shut down cleanly when the host is powering off.
    onShutdown = "shutdown";
    parallelShutdown = 2;

    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;

      # Enables VirtioFS-backed host directory sharing in guest definitions.
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  # Make dnsmasq available to the libvirtd daemon for DHCP and DNS on the
  # default NAT network, without adding it to the interactive system profile.
  systemd.services.libvirtd.path = [ pkgs.dnsmasq ];

  # Keep the default NAT network available after boot rather than requiring
  # one-time manual virsh net-start and net-autostart commands.
  systemd.services.libvirt-default-network = {
    description = "Start and autostart the libvirt default NAT network";
    wantedBy = [ "multi-user.target" ];
    requires = [ "libvirtd.service" ];
    after = [ "libvirtd.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      # The helper only talks to the local libvirt UNIX socket. Keep /etc
      # writable for libvirt's autostart symlink, but isolate everything else.
      ProtectSystem = "full";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
    };

    script = ''
      ${virsh} -c qemu:///system net-autostart default

      if ! ${virsh} -c qemu:///system net-list --name | ${pkgs.gnugrep}/bin/grep -Fxq default; then
        ${virsh} -c qemu:///system net-start default
      fi
    '';
  };

  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
}
