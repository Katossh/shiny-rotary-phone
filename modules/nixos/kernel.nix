{
  config,
  lib,
  ...
}:

let
  nativeCpuOptimization = config.starforge.kernel.nativeCpuOptimization.enable;

  kernelSettings =
    with lib.kernel;
    {
      # Linux upstream supports 100, 250, 300, and 1000 Hz.
      HZ_1000 = yes;

      # Keep runtime-selectable preemption and choose full mode at boot.
      PREEMPT_DYNAMIC = yes;

      # sched_ext requires BPF, BTF metadata, and the extensible scheduler class.
      BPF = yes;
      BPF_SYSCALL = yes;
      DEBUG_INFO_BTF = yes;
      SCHED_CLASS_EXT = yes;

      # Use tickless idle, not full dynticks. These options are mutually
      # exclusive; Nixpkgs enables NO_HZ_FULL for 64-bit kernels by default.
      NO_HZ_IDLE = yes;
      NO_HZ_FULL = no;

      # Request Clang ThinLTO when the active kernel/toolchain combination
      # satisfies upstream Kconfig's prerequisites. Keep it optional because
      # Kconfig may hide it even when Clang/LLD are selected.
      LTO_CLANG_THIN = option yes;

      # Keep symmetric multiprocessing enabled.
      SMP = yes;
    }
    // lib.optionalAttrs nativeCpuOptimization {
      # CONFIG_X86_NATIVE_CPU uses -march=native on the machine that compiles
      # the kernel. This is enabled for the local Ryzen workstation only;
      # CI builds a separate portable kernel to avoid caching runner-specific
      # machine code.
      X86_NATIVE_CPU = yes;
    };
in
{
  options.starforge.kernel.nativeCpuOptimization.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    internal = true;
    description = ''
      Build the workstation kernel for the CPU on the machine compiling it.
      Disabled for CI builds, which run on a different CPU.
    '';
  };

  # CONFIG_PREEMPT_DYNAMIC allows selecting full kernel preemption at boot.
  config.boot.kernelParams = [ "preempt=full" ];

  config.boot.kernelPatches = [
    {
      name = "workstation-kernel-configuration";
      patch = null;
      structuredExtraConfig = lib.mapAttrs (_: lib.mkForce) kernelSettings;
    }
  ];
}
