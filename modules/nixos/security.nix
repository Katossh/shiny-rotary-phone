{ ... }:

{
  # Keep the host firewall enabled and do not expose services by default.
  # The default iptables backend is retained for libvirt compatibility.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  # USBGuard starts from a conservative bootstrap policy:
  # - devices already present keep their current authorization state;
  # - newly inserted devices are blocked unless explicitly approved;
  # - unknown devices default to block.
  #
  # The rule file remains host-local and writable at
  # /var/lib/usbguard/rules.conf so root can persist approved device rules.
  services.usbguard = {
    enable = true;
    implicitPolicyTarget = "block";
    presentDevicePolicy = "keep";
    presentControllerPolicy = "keep";
    insertedDevicePolicy = "block";
  };

  # Wait until the initial udev coldplug has settled before USBGuard snapshots
  # present devices. This avoids racing the initial keyboard/mouse enumeration.
  systemd.services.usbguard = {
    wants = [ "systemd-udev-settle.service" ];
    after = [ "systemd-udev-settle.service" ];
  };

  security = {
    protectKernelImage = true;

    sudo = {
      wheelNeedsPassword = true;
      extraConfig = ''
        Defaults timestamp_timeout=5
      '';
    };

    # Audit privileged command execution. This is deliberately narrower than
    # auditing every syscall, which would create substantial desktop noise.
    audit = {
      enable = true;
      rules = [
        "-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged_exec"
        "-a always,exit -F arch=b32 -S execve -F euid=0 -k privileged_exec"
      ];
    };

    auditd.enable = true;
  };

  boot.kernelParams = [
    "slab_nomerge"
    "page_alloc.shuffle=1"
    "randomize_kstack_offset=on"
  ];

  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;

    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;

    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
  };
}
