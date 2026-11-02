{ pkgs, ... }:

{
  security.apparmor = {
    enable = true;

    # Do not terminate desktop processes automatically when profiles change.
    # New policies are introduced in complain mode and promoted deliberately.
    killUnconfinedConfinables = false;

    policies.curl = {
      # Start in observation mode: operations that would be denied in enforce
      # mode are logged but allowed. Use real workload logs before tightening.
      state = "complain";
      profile = ''
        abi <abi/4.0>,
        include <tunables/global>

        profile ${pkgs.curl}/bin/curl {
          include <abstractions/base>
          include <abstractions/nameservice>
          include <abstractions/ssl_certs>

          network inet stream,
          network inet dgram,
          network inet6 stream,
          network inet6 dgram,
        }
      '';
    };
  };

  # Keep the executable being observed available in the system profile.
  environment.systemPackages = [ pkgs.curl ];
}
