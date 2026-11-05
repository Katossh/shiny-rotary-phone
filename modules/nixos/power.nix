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

  # These services expose battery and user-selectable power profiles to the
  # desktop shell. They are power-management services, not hardware setup.
  services = {
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };
}
