# Installing Starforge

`install.sh` applies the Starforge NixOS flake from a minimal NixOS environment.
The only extra package you need to fetch the repository is Git; Nix and the
NixOS installation tools are supplied by NixOS itself.

> **Hardware scope:** this flake is currently a profile for the existing
> `starforge` workstation, not a generic multi-host installer. It expects the
> encrypted Btrfs root UUID `fb18dd0b-4f76-449f-9d00-67cc9d49b4ee`, the FAT32
> `/boot` UUID `FD77-5C81`, the Btrfs subvolumes `@root`, `@home`, `@nix`, and
> `@var-log`, UEFI boot, and the Windows ESP partition GUID
> `68a6f3c1-1eee-4845-8c3e-7108cec34c4a`. The script checks these identifiers
> and refuses to apply the profile when they do not match.

The script never partitions disks, formats filesystems, creates Btrfs
subvolumes, changes LUKS keys, or enrolls Secure Boot keys.

## Existing Starforge installation

From the running Starforge system:

~~~sh
git clone https://github.com/Katossh/shiny-rotary-phone.git ~/starforge
cd ~/starforge
sudo ./install.sh
~~~

The script verifies the host's disk identifiers and mount layout, then runs
`nixos-rebuild switch --flake .#starforge`. Nix evaluates and builds the new
generation before activating it. The existing `flake.lock` is used; dependencies
are not deliberately updated as part of installation.

For a temporary activation that does not change the default boot generation:

~~~sh
sudo ./install.sh --test
~~~

After testing the desktop, networking, audio, Bluetooth, boot menu, and other
hardware, make the configuration permanent with:

~~~sh
sudo ./install.sh --switch
~~~

To update the repository and apply the reviewed changes:

~~~sh
git pull --ff-only
sudo ./install.sh
~~~

## Terminal environment

Starforge pins [terminal-dotfiles](https://github.com/Katossh/terminal-dotfiles) as a
non-flake input. Home Manager reads its `manifest/configs.tsv` and links the
declared terminal configurations into the user's XDG config directories and
home directory. The dotfiles repository remains the single source of truth;
the files are not copied into Starforge.

The NixOS terminal module also reads `manifest/packages.tsv` to install the
declared terminal packages. Home Manager supplies the user-level integration:
Zsh startup files, Oh My Zsh and its plugins, Kitty's generated palette, the
tmux palette adapter, and the executable helper scripts (excluding the
imperative `dots` installer).

Do not run `dots install` on Starforge: Home Manager owns the managed paths.
Existing files that collide with Home Manager targets are preserved using the
configured `.hm-backup` suffix.

To update the terminal environment, update the pinned input, review the lock
file change, and rebuild:

~~~sh
nix flake lock --update-input terminal-dotfiles
sudo nixos-rebuild switch --flake .#starforge
~~~

## Fresh installation from the NixOS ISO

This path reinstalls the Starforge profile onto its **existing disk layout**.
Boot the official NixOS x86_64 installer in UEFI mode, connect to the network,
and open the existing LUKS container. The NixOS installer already provides Nix
and the NixOS installation tools; Git is the only additional tool needed to
fetch this repository.

The following commands only open and mount existing filesystems. They do not
format disks. Confirm the UUIDs and existing Btrfs subvolumes before running
them:

~~~sh
sudo -i
cryptsetup open /dev/disk/by-uuid/fb18dd0b-4f76-449f-9d00-67cc9d49b4ee cryptroot

mount -o subvol=@root /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{boot,home,nix,var/log,etc/nixos}
mount -o subvol=@home /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@var-log /dev/mapper/cryptroot /mnt/var/log
mount /dev/disk/by-uuid/FD77-5C81 /mnt/boot

git clone https://github.com/Katossh/shiny-rotary-phone.git /mnt/etc/nixos/starforge
cd /mnt/etc/nixos/starforge
./install.sh --install
~~~

The script verifies that `/mnt`, `/mnt/home`, `/mnt/nix`, `/mnt/var/log`, and
`/mnt/boot` are mounted with the expected filesystem types and Btrfs subvolumes.
It then runs `nixos-install --flake ...#starforge`, asks you to set the root
password, and prompts you to set the `katossh` account password inside the new
system. Set both passwords before rebooting.

Do not run the fresh-install mode against a newly partitioned or different
computer. The committed hardware configuration and Limine Windows entry are
specific to Starforge. A different machine needs its own host profile and
hardware configuration first.

## Why this does not run on an arbitrary Linux distribution

A Git-only Ubuntu, Fedora, or other Linux installation cannot directly activate
a NixOS system configuration: it does not provide `nixos-rebuild` or the NixOS
boot and service infrastructure. Boot the NixOS installer ISO first. The
standard installation flow still requires the target filesystems to be
prepared and mounted manually; `nixos-install --flake` then installs the
selected flake configuration.

See the [NixOS installation manual](https://nixos.org/manual/nixos/stable/#sec-installation) for
preparing and mounting target filesystems and installing a flake.
