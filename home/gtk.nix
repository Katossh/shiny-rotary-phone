_:

{
  # GTK widgets implement PRIMARY-selection paste themselves; disabling it
  # here complements Niri's compositor-level disable-primary setting.
  gtk = {
    gtk3.extraConfig."gtk-enable-primary-paste" = false;
    gtk4.extraConfig."gtk-enable-primary-paste" = false;
  };
}
