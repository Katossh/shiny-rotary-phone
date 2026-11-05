{ config, pkgs, ... }:

let
  virsh = "${config.virtualisation.libvirtd.package}/bin/virsh";

  # These short-lived helper units prepare libvirt state or request that its
  # local NAT network is started. They do not need hardware devices, IP
  # networking, or direct access to kernel-management interfaces.
  helperServiceHardening = {
    NoNewPrivileges = true;
    ProtectSystem = "full";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    RestrictAddressFamilies = [ "AF_UNIX" ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    SystemCallArchitectures = "native";
  };
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

  # Keep the default NAT network available after boot, while assigning the
  # libvirt system socket only to the workstation account.
  systemd = {
    services = {
      libvirtd.path = [ pkgs.dnsmasq ];

      # The NixOS-generated setup helper only populates /var/lib/libvirt and
      # /run/libvirt from immutable Nix-store inputs.
      libvirtd-config.serviceConfig = helperServiceHardening;

      libvirt-default-network = {
        description = "Start and autostart the libvirt default NAT network";
        wantedBy = [ "multi-user.target" ];
        requires = [ "libvirtd.service" ];
        after = [ "libvirtd.service" ];

        # This helper only talks to libvirtd over its local UNIX socket.
        # The shared profile keeps /etc writable for libvirt's autostart
        # symlink while removing unrelated device, kernel, and namespace access.
        serviceConfig = helperServiceHardening // {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          ${virsh} -c qemu:///system net-autostart default

          if ! ${virsh} -c qemu:///system net-list --name | ${pkgs.gnugrep}/bin/grep -Fxq default; then
            ${virsh} -c qemu:///system net-start default
          fi
        '';
      };
    };

    sockets.libvirtd.socketConfig = {
      SocketUser = "katossh";
      SocketGroup = "root";
      SocketMode = "0600";
    };
  };

  # Grant libvirt management only to the interactive local workstation user.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.libvirt.unix.manage" &&
          subject.user == "katossh" &&
          subject.active == true &&
          subject.local == true) {
        return polkit.Result.YES;
      }
    });
  '';

  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
}
