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

      # Use tickless idle, not full dynticks. These options are mutually
      # exclusive; Nixpkgs enables NO_HZ_FULL for 64-bit kernels by default.
      NO_HZ_IDLE = yes;
      NO_HZ_FULL = no;

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

  config.boot.kernelPatches = [
    {
      name = "workstation-kernel-configuration";
      patch = null;
      structuredExtraConfig = lib.mapAttrs (_: lib.mkForce) kernelSettings;
    }
  ];
}
