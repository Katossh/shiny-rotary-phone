{ ... }:

{
  # Physical display topology for this workstation. Discover output names with
  # "niri msg outputs" from the running Wayland session.
  home-manager.users.katossh.starforge.user.desktop.monitors = {
    "DP-1" = {
      # Preserve the current resolution. Without an explicit refresh rate,
      # Niri selects the highest advertised refresh rate for this mode.
      mode = "3440x1440";
    };
  };
}
