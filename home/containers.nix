{ config, pkgs, ... }:

let
  dockerRepository = "${config.home.homeDirectory}/Docker";
  routerLauncher = "${dockerRepository}/scripts/9router.sh";
in
{
  # Keep the user-facing container tools and their provider selection together.
  home.sessionVariables = {
    DBX_CONTAINER_MANAGER = "podman";
    PODMAN_COMPOSE_PROVIDER = "${pkgs.podman-compose}/bin/podman-compose";
  };

  home.packages = with pkgs; [
    distrobox
    podman-compose
  ];

  # The Compose definition and its runtime secrets live in the separate
  # Katossh/Docker repository. NixOS only owns lifecycle integration here.
  # The unit is skipped until that repository is checked out at ~/Docker.
  systemd.user.services."9router" = {
    Unit = {
      Description = "9Router AI gateway (rootless Podman Compose)";
      ConditionPathIsExecutable = routerLauncher;
      Wants = [ "podman-restart.service" ];
      After = [ "podman-restart.service" ];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = dockerRepository;
      Environment = [
        "CONTAINER_ENGINE=/run/current-system/sw/bin/podman"
        "PODMAN_COMPOSE_PROVIDER=${pkgs.podman-compose}/bin/podman-compose"
        "PATH=${pkgs.coreutils}/bin:${pkgs.gnused}/bin:/run/current-system/sw/bin"
      ];
      ExecStart = "${routerLauncher} up";
      ExecStop = "${routerLauncher} down";
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = 0;
      TimeoutStopSec = 60;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
