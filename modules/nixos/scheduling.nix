{ lib, ... }:

{
  # scx-loader replaces services.scx in the updated Nixpkgs input. Keep
  # scx_lavd as the boot scheduler and preserve the previous --performance
  # argument through the loader's Auto-mode configuration.
  services.scx-loader = {
    enable = true;

    config = {
      default_sched = "scx_lavd";
      default_mode = "Auto";
      scheds.scx_lavd.auto_mode = [ "--performance" ];
    };
  };

  # Avoid overlapping per-process scheduling policy while sched_ext is active.
  services.ananicy.enable = lib.mkForce false;
}
