# 9Router

9Router is deployed as a NixOS-managed OCI container using the Docker backend.
It starts with the workstation and is supervised by systemd. Podman remains
available as the rootless runtime for Distrobox; the Docker daemon is used for
this system service.

## Access

Open the dashboard at:

- http://127.0.0.1:20128

The published port is explicitly bound to loopback. The dashboard and API are
not exposed to the LAN. The OpenAI-compatible endpoint is:

- http://127.0.0.1:20128/v1

On first boot, the NixOS service generates a random dashboard bootstrap
password and persistent signing secrets on the host. Read the password with:

```sh
sudo cat /var/lib/9router/initial-password
```

Log in and change the dashboard password immediately. Create an API key in
9Router and use that key in clients. The `REQUIRE_API_KEY` setting is enabled,
so API requests to `/v1/*` must carry a Bearer API key.

## Persistent state and secrets

- Application database, provider connections, settings, and backups:
  `/var/lib/9router/data`.
- Generated environment secrets:
  `/var/lib/9router/secrets.env` (root-owned, mode `0600`).
- Initial dashboard password:
  `/var/lib/9router/initial-password` (root-owned, mode `0600`).

The secret file contains randomly generated `INITIAL_PASSWORD`, `JWT_SECRET`,
`API_KEY_SECRET`, and `MACHINE_ID_SALT` values. It is generated once, persists
across restarts, is not stored in Git or the Nix store, and is not mounted into
the application container. Do not delete it while keeping the existing
database: doing so would rotate signing material and change the bootstrap
password fallback.

Do not add the workstation user to the `docker` group. Access to the Docker
daemon is effectively root access; manage this service through its systemd
unit instead.

## Service management

```sh
sudo systemctl status docker-9router.service
sudo journalctl -u docker-9router.service -f
sudo systemctl restart docker-9router.service
sudo systemctl stop docker-9router.service
sudo systemctl start docker-9router.service
```

## Updating

The NixOS module pins the published image tag `decolua/9router:0.5.116`
instead of following the mutable `latest` tag. To update, verify that a
versioned Docker image has been published upstream, change the image tag in
`modules/nixos/containers.nix`, then rebuild and test the workstation
configuration. The OCI service pulls the new tag when it is missing locally.

```sh
sudo nixos-rebuild test --flake .#workstation
sudo systemctl status docker-9router.service
```

The current image version is intentionally pinned; checking for newer upstream
releases and changing the version are deliberate maintenance actions.
