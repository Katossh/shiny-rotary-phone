{ pkgs, ... }:

let
  starforge = pkgs.writeShellApplication {
    name = "starforge";
    runtimeInputs = with pkgs; [
      amdgpu_top
      coreutils
      diffutils
      findutils
      gawk
      git
      lm_sensors
      nix
      nixfmt
      procps
      systemd
    ];
    text = builtins.readFile ../../scripts/starforge.sh;
  };
in
{
  environment.systemPackages = [ starforge ];
}
