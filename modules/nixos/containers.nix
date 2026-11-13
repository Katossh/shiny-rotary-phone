{ pkgs, ... }:

{
  # Podman remains the rootless runtime for Distrobox. The 9Router system
  # service below uses the real Docker engine through NixOS oci-containers.
  # Docker's CLI cannot coexist with Podman's compatibility alias.
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;

    # Enable service-name DNS on the default bridge network for Compose stacks.
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.oci-containers = {
    backend = "docker";

    containers."9router" = {
      # Pin a published multi-platform image instead of tracking mutable latest.
      image = "decolua/9router:0.5.116";
      pull = "missing";
      autoStart = true;

      # Keep the dashboard and API on the local machine only.
      ports = [ "127.0.0.1:20128:20128" ];
      volumes = [ "/var/lib/9router/data:/app/data" ];

      environment = {
        DATA_DIR = "/app/data";
        PORT = "20128";
        HOSTNAME = "0.0.0.0";
        NODE_ENV = "production";
        BASE_URL = "http://127.0.0.1:20128";
        NEXT_PUBLIC_BASE_URL = "http://127.0.0.1:20128";
        REQUIRE_API_KEY = "true";
        ENABLE_REQUEST_LOGS = "false";
      };

      # Secrets are generated on the host and read by Docker at container start.
      # This file is not mounted into the container or copied into the Nix store.
      environmentFiles = [ "/var/lib/9router/secrets.env" ];

      extraOptions = [
        "--security-opt=no-new-privileges:true"
      ];
    };
  };

  systemd.services = {
    "9router-secrets" = {
      description = "Create persistent local credentials for 9Router";
      wantedBy = [ "multi-user.target" ];
      before = [ "docker-9router.service" ];
      after = [ "local-fs.target" ];

      path = [
        pkgs.coreutils
        pkgs.openssl
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };

      script = ''
        set -euo pipefail

        state_dir="/var/lib/9router"
        secrets_file="$state_dir/secrets.env"
        password_file="$state_dir/initial-password"

        ${pkgs.coreutils}/bin/install -d -m 0700 -o root -g root "$state_dir"

        if [ ! -s "$secrets_file" ]; then
          initial_password="$("${pkgs.openssl}/bin/openssl" rand -hex 24)"
          jwt_secret="$("${pkgs.openssl}/bin/openssl" rand -hex 32)"
          api_key_secret="$("${pkgs.openssl}/bin/openssl" rand -hex 32)"
          machine_id_salt="$("${pkgs.openssl}/bin/openssl" rand -hex 32)"

          secrets_tmp="$("${pkgs.coreutils}/bin/mktemp" "$state_dir/.secrets.env.XXXXXX")"
          password_tmp="$("${pkgs.coreutils}/bin/mktemp" "$state_dir/.initial-password.XXXXXX")"
          trap '"${pkgs.coreutils}/bin/rm" -f "$secrets_tmp" "$password_tmp"' EXIT

          {
            printf 'INITIAL_PASSWORD=%s\n' "$initial_password"
            printf 'JWT_SECRET=%s\n' "$jwt_secret"
            printf 'API_KEY_SECRET=%s\n' "$api_key_secret"
            printf 'MACHINE_ID_SALT=%s\n' "$machine_id_salt"
          } > "$secrets_tmp"

          printf '%s\n' "$initial_password" > "$password_tmp"
          "${pkgs.coreutils}/bin/chmod" 0600 "$secrets_tmp" "$password_tmp"
          "${pkgs.coreutils}/bin/mv" "$password_tmp" "$password_file"
          "${pkgs.coreutils}/bin/mv" "$secrets_tmp" "$secrets_file"
        fi
      '';
    };

    # The OCI module generates this unit name from backend + container name.
    # Ensure its environment file exists before Docker reads it.
    "docker-9router" = {
      requires = [ "9router-secrets.service" ];
      after = [ "9router-secrets.service" ];
    };
  };

  # The Podman package ships this rootless user unit. It starts containers
  # whose restart policy is "always" or "unless-stopped" after each boot.
  systemd.user.services.podman-restart.wantedBy = [ "default.target" ];
}
