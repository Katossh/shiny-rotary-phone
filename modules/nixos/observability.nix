{ pkgs, ... }:

let
  nixcfg = pkgs.writeShellApplication {
    name = "nixcfg";
    runtimeInputs = with pkgs; [
      amdgpu_top
      coreutils
      diffutils
      findutils
      gawk
      gnugrep
      git
      inetutils
      lm_sensors
      nix
      nixfmt
      procps
      systemd
      util-linux
    ];
    text = builtins.readFile ../../scripts/nixcfg.sh;
  };
in
{
  environment.systemPackages = [ nixcfg ];
}
