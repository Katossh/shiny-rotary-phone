{ pkgs, ... }:

{
  # NixOS 26.11 uses scx-loader (services.scx was removed). Keep LAVD as
  # the default while installing the Rust scheduler collection, which also
  # provides scx_bpfland for manual runtime comparison.
  services.scx-loader = {
    enable = true;
    schedsPackages = [ pkgs.scx.rustscheds ];
    config.default_sched = "scx_lavd";
  };

  # The C++ daemon intentionally ships without rules. Use the maintained
  # CachyOS rule set; the legacy pkgs.ananicy alias was removed from Nixpkgs.
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };
}
