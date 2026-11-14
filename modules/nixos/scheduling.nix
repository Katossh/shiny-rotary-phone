{ ... }:

{
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
    extraArgs = [ "--performance" ];
  };

  # Avoid overlapping per-process scheduling policy while sched_ext is active.
  services.ananicy.enable = false;
}
