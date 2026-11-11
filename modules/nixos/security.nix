{ config, ... }:

{
  security = {
    polkit.enable = true;
    protectKernelImage = true;

    # Local inference can mlock model/runtime buffers. PAM limits are in KiB;
    # keep this scoped to the configured interactive user.
    pam.loginLimits = [
      {
        domain = config.starforge.user.username;
        type = "soft";
        item = "memlock";
        value = "8388608";
      }
      {
        domain = config.starforge.user.username;
        type = "hard";
        item = "memlock";
        value = "8388608";
      }
    ];

    sudo = {
      wheelNeedsPassword = true;
      extraConfig = ''
        Defaults timestamp_timeout=15
        Defaults passwd_tries=3
        Defaults insults
        Defaults use_pty
      '';
    };

    # Audit privileged command execution. This is deliberately narrower than
    # auditing every syscall, which would create substantial desktop noise.
    audit = {
      enable = true;

      # The kernel reported backlog exhaustion at the 1024-entry Nixpkgs
      # default. Increase the queue to absorb larger audit-event bursts.
      backlogLimit = 8192;

      rules = [
        "-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged_exec"
        "-a always,exit -F arch=b32 -S execve -F euid=0 -k privileged_exec"
      ];
    };

    auditd.enable = true;
  };

  # user@.service owns the per-user systemd manager. PAM limits do not cover
  # this unit, so raise its ceiling explicitly; the manager then passes the
  # configured default to services it starts.
  systemd.services."user@".serviceConfig.LimitMEMLOCK = "8G:8G";

  # Default RLIMIT_MEMLOCK for services launched by the per-user manager.
  systemd.user.settings.Manager.DefaultLimitMEMLOCK = "8G:8G";

  # Kernel and network-stack hardening belongs to the security policy even
  # though some of the affected sysctls are networking-related.
  # Maximum lockdown level: block both kernel modification and userspace reads
  # of confidential kernel data, subject to kernel support.
  boot.kernelParams = [
    "lockdown=confidentiality"
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
