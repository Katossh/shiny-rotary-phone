{ pkgs, ... }:

{
  # KVM/QEMU managed through libvirt. QEMU guests run as the dedicated
  # unprivileged qemu-libvirtd account rather than as root.
  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
    };
  };

  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
}
