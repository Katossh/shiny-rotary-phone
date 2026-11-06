{ config, lib, pkgs, ... }:

let
  cfg = config.starforge.user.hardware.deepcoolDigital;
  package = pkgs.deepcool-digital-linux;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ package ];

    systemd.user.services.deepcool-digital-linux = {
      Unit.Description = "DeepCool Digital display daemon";

      Service = {
        ExecStart = lib.getExe package;
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
