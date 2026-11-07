{ pkgs, ... }:

{
  # Bubblewrap is a low-level, unprivileged sandbox builder. Keep the host
  # package available without installing a setuid wrapper or changing the
  # kernel's unprivileged-user-namespace policy.
  environment.systemPackages = [ pkgs.bubblewrap ];
}
