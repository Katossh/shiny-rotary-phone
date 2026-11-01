# NixOS configuration

NixOS configuration for the `starforge` host.

## Included

- GRUB on UEFI
- LUKS-encrypted Btrfs root with separate Btrfs subvolumes
- Niri compositor and Noctalia shell
- greetd with tuigreet
- PipeWire audio
- Firefox, Kitty, and XWayland compatibility
- Terminal packages and fonts from [terminal-dotfiles](https://github.com/Katossh/terminal-dotfiles)
- AMD firmware and microcode updates

## Apply the configuration

The flake exports the host as `nixos`, so use that attribute (not the machine hostname):

```sh
nix fmt
nix flake check
sudo nixos-rebuild build --flake '.#nixos'
sudo nixos-rebuild test --flake '.#nixos'
```

After verifying that the test activation works, make it the active system generation:

```sh
sudo nixos-rebuild switch --flake '.#nixos'
```

Run these commands from the directory containing `flake.nix`. Keep `flake.lock` committed so the system uses the reviewed input revisions.

## Important notes

- Do not change `system.stateVersion` just to follow a newer NixOS release. It controls compatibility defaults and should remain at the version used when the system was first installed.
- `hardware-configuration.nix` contains machine-specific disk UUIDs, mount points, and filesystem settings. Do not copy it to another host unchanged.
- Review changes to the bootloader, LUKS device, filesystem layout, and kernel before applying them. Keep a working rollback generation available.
- The configuration currently tracks `nixos-unstable` and the Noctalia `cachix` branch. Updates can introduce breaking changes; update inputs deliberately and review the resulting diff.
