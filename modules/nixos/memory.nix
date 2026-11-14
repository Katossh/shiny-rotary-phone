_:

{
  # Keep ordinary /tmp on the root filesystem. The separate RAM-backed
  # workspace is opt-in, so large builds can continue using normal /tmp.
  boot.tmp.useTmpfs = false;

  fileSystems."/tmp/ram" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=1777"
      "nosuid"
      "nodev"
      "size=4G"
    ];
  };

  # Compressed RAM swap absorbs short memory spikes without writing VM or
  # application pages to an unencrypted disk swap device.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Keep the desktop user's cgroup outside oomd's kill policy. Under sustained
  # memory pressure, make VM cgroups in machine.slice eligible instead.
  systemd.oomd = {
    enable = true;
    enableUserSlices = false;
  };

  systemd.slices."machine".sliceConfig = {
    MemoryAccounting = true;
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMMemoryPressureLimit = "75%";
    ManagedOOMMemoryPressureDurationSec = "30s";
  };
}
