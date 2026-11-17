_:

{
  # No persistent swap/resume target is configured. zram alone cannot provide
  # a hibernation image, so disable hibernation-related sleep modes explicitly.
  environment.etc."systemd/sleep.conf.d/20-nixos.conf".text = ''
    [Sleep]
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # Configure the physical power key and expose power-management services to
  # the desktop shell.
  services = {
    logind.settings.Login.HandlePowerKey = "poweroff";
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };
}
