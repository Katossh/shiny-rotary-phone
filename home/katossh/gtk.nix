_:

{
  # GTK applications implement middle-click paste themselves. This disables
  # PRIMARY selection pasting in both GTK settings backends.
  gtk = {
    gtk3.extraConfig."gtk-enable-primary-paste" = false;
    gtk4.extraConfig."gtk-enable-primary-paste" = false;
  };
}
