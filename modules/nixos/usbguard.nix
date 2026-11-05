_:

{
  services.usbguard = {
    enable = true;

    # This host uses USBGuard for visibility and selective manual controls,
    # not as a device allowlist. Unknown devices remain usable by default.
    implicitPolicyTarget = "allow";

    # Do not change the authorization state of devices already connected when
    # the daemon starts. New devices are evaluated against the mutable rule
    # file; unmatched devices inherit the permissive default above.
    presentDevicePolicy = "keep";
    presentControllerPolicy = "keep";
    insertedDevicePolicy = "apply-policy";

    # Keep policy administration local to root. The D-Bus/Polkit interface is
    # unnecessary for this workstation and would expand the control surface.
    IPCAllowedUsers = [ "root" ];
    IPCAllowedGroups = [ ];
    dbus.enable = false;
  };
}
