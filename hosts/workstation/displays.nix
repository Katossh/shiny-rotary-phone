{ ... }:

{
  # Physical display topology for this workstation. Discover output names with
  # "niri msg outputs" from the running Wayland session.
  home-manager.users.katossh.starforge.user.desktop.monitors = {
    "DP-1" = {
      # Preserve the current mode preference; no refresh rate is pinned.
      mode = "3440x1440";
    };
  };
}
