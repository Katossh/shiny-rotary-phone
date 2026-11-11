# Installing the NixOS configuration

`install.sh` applies the workstation NixOS flake from a minimal NixOS environment.
The only extra package you need to fetch the repository is Git; Nix and the
NixOS installation tools are supplied by NixOS itself.

> **Hardware scope:** this remains one `workstation` profile for the project's
> AMD x86_64 machine, using UEFI and a single NixOS boot entry. It is not a
> generic profile for arbitrary computers. The ISO installer detects the
> mounted root, EFI, and any additional mounted filesystems and regenerates
> `hosts/workstation/hardware-configuration.nix`; it no longer depends on
> hard-coded partition UUIDs or Btrfs subvolume names. The host-specific CPU,
> GPU, display, and device modules still need to match the target hardware.

The script never partitions disks, formats filesystems, creates Btrfs
subvolumes, changes LUKS keys, or creates/enrolls Secure Boot keys.

## Existing NixOS installation

From the running NixOS system:

~~~sh
git clone https://github.com/Katossh/shiny-rotary-phone.git ~/nixos-config
cd ~/nixos-config
sudo ./install.sh
~~~

The script compares the running root and `/boot` devices and filesystem types
with the generated host configuration, then runs
`nixos-rebuild switch --flake .#workstation`. Nix evaluates and builds the new
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

## Gaming

The workstation profile enables Steam through `programs.steam.enable`, installs
`osu-lazer-bin`, and imports the upstream
[aagl-gtk-on-nix](https://github.com/ezKEa/aagl-gtk-on-nix) NixOS module for
Genshin Impact. All three are installed declaratively through the system
configuration; Flatpak is not required.

The launcher is enabled with `programs.anime-game-launcher.enable = true`.
The AAGL flake and its dependencies are pinned in `flake.lock`, and its
Cachix binary cache is configured to avoid compiling the launcher locally.
The upstream module also enables its `networking.mihoyo-telemetry.block`
hosts rules when the launcher is enabled.

After applying the NixOS generation, launch **An Anime Game Launcher** from the
application menu (or run `anime-game-launcher`) and follow its setup to
download Genshin Impact. This is an unofficial community launcher, not a
HoYoverse product; Linux compatibility is not officially supported and may
break after game updates.

`osu-lazer-bin` is the upstream AppImage build with online score submission
and multiplayer. Its version follows the pinned Nixpkgs revision in
`flake.lock`.

## Terminal environment

The workstation profile pins [terminal-dotfiles](https://github.com/Katossh/terminal-dotfiles) as a
non-flake input. Home Manager reads its `manifest/configs.tsv` and links the
declared terminal configurations into the user's XDG config directories and
home directory. The dotfiles repository remains the single source of truth;
the files are not copied into this repository.

The NixOS terminal module also reads `manifest/packages.tsv` to install the
declared terminal packages. Home Manager supplies the user-level integration:
Zsh startup files, Oh My Zsh and its plugins, Kitty's generated palette, the
tmux palette adapter, and the executable helper scripts (excluding the
imperative `dots` installer).

Do not run `dots install` on this NixOS system: Home Manager owns the managed paths.
Existing files that collide with Home Manager targets are preserved using the
configured `.hm-backup` suffix.

To update the terminal environment, update the pinned input, review the lock
file change, and rebuild:

~~~sh
nix flake lock --update-input terminal-dotfiles
sudo nixos-rebuild switch --flake .#workstation
~~~

## Fresh installation from the NixOS ISO

This mode installs the existing `workstation` profile onto filesystems that
you have already prepared and mounted. It supports different partition UUIDs
and mount layouts, including a simple single-boot layout. It does not decide
how your disk should be partitioned and does not create or format filesystems.

### 1. Boot the ISO and connect to the network

Boot the official NixOS x86_64 ISO in **UEFI mode**. The graphical ISO is
convenient, but a desktop is not required: the installer can be driven from a
terminal.

For Wi-Fi, open a terminal and run:

~~~sh
sudo -i
nmtui
~~~

Choose **Activate a connection**, select your Wi-Fi network, and enter its
password. `nmtui` is NetworkManager's terminal interface and also works in a
non-graphical installer session. Verify connectivity before continuing:

~~~sh
curl -I https://github.com
~~~

The NixOS installer provides Nix and the NixOS installation tools.
Git may already be available in the ISO. If it is not, the final step below
shows how to run the clone and installer in a temporary shell that provides Git.

### 2. Identify the existing filesystems

Inspect the current layout before mounting anything:

~~~sh
lsblk -f
blkid
~~~

Identify the intended root filesystem and an **unencrypted FAT32 EFI
partition** for NixOS at `/boot`. This profile uses Limine in UEFI mode and
expects the EFI filesystem to be mounted at `/boot`.

The installer deliberately does not include `parted`, `mkfs`, `wipefs`,
`btrfs subvolume create`, or any other partitioning/formatting step. If the
target layout does not exist yet, prepare it separately and verify the device
names and backup/recovery plan before proceeding.

### 3. Open encryption and mount the target layout

For an unencrypted root filesystem, mount the existing root partition:

~~~sh
mkdir -p /mnt
mount /dev/<root-partition> /mnt
~~~

For a LUKS-encrypted root, unlock the existing container first. The mapper
name below is just an example; `cryptroot` is the name requested by the
mount/configuration, not a partition name or a fixed UUID:

~~~sh
cryptsetup open /dev/disk/by-uuid/<LUKS-UUID> cryptroot
mount /dev/mapper/cryptroot /mnt
~~~

If the Btrfs root is an existing subvolume, specify its actual name when
mounting it. For example, use `subvol=@root` only if that subvolume really
exists:

~~~sh
mount -o subvol=@root /dev/mapper/cryptroot /mnt
~~~

For a simple ext4 or Btrfs root without separate `/home`, `/nix`, or
`/var/log` filesystems, no additional data mounts are required. Mount the
existing EFI partition separately:

~~~sh
mkdir -p /mnt/boot /mnt/etc/nixos
mount /dev/disk/by-uuid/<EFI-FILESYSTEM-UUID> /mnt/boot
~~~

If your existing layout has separate filesystems or Btrfs subvolumes for
`/home`, `/nix`, `/var`, or `/var/log`, mount each one at its corresponding
path under `/mnt` before running the installer. This includes a separate
`/var` filesystem containing the existing sbctl keys. For example, only when those
subvolumes exist:

~~~sh
mkdir -p /mnt/home /mnt/nix /mnt/var/log
mount -o subvol=@home /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@var-log /dev/mapper/cryptroot /mnt/var/log
~~~

The installer detects the filesystems that are actually mounted below
`/mnt`. It does not assume these example names. A LUKS mapper such as
`/dev/mapper/cryptroot` is detected by `nixos-generate-config`, which emits
the corresponding initrd LUKS mapping and underlying device identifier into
the generated hardware configuration.

### 4. Preserve the Secure Boot signing keys

This workstation profile enables Limine Secure Boot. The installation checks
for the existing sbctl database signing key and certificate under:

~~~text
/mnt/var/lib/sbctl/keys/db/db.key
/mnt/var/lib/sbctl/keys/db/db.pem
~~~

Restore the **complete existing `/var/lib/sbctl` key directory** from a
trusted offline backup to the target filesystem before installation. If the
target root is being reformatted, the keys on that root will be erased unless
you back them up first. Keep private keys off the Git repository and never
paste them into chat or logs.

The installer stops when the required keys are missing. It does not generate
or enroll replacement keys automatically. A machine without the existing
trusted keys needs a separately planned Secure Boot setup before this profile
can be installed.

### 5. Clone the repository and install

With Git available in the current shell:

~~~sh
git clone https://github.com/Katossh/shiny-rotary-phone.git /mnt/etc/nixos
cd /mnt/etc/nixos
./install.sh --install
~~~

If Git is missing from the live ISO, run the same commands inside a temporary
environment that provides it:

~~~sh
nix-shell -p git --run '
  git clone https://github.com/Katossh/shiny-rotary-phone.git /mnt/etc/nixos
  cd /mnt/etc/nixos
  ./install.sh --install
'
~~~

The target root must already be mounted and `/mnt/etc/nixos` must not contain
an unrelated non-empty directory. If a previous configuration exists there,
back it up and decide how to preserve it before cloning; the installer will
not delete or replace an existing repository automatically.

The script then:

1. Confirms that `/mnt` is the target root and `/mnt/boot` is a separate,
   unencrypted FAT32 filesystem.
2. Runs `nixos-generate-config --root /mnt --show-hardware-config` and
   atomically replaces the repository's generated
   `hosts/workstation/hardware-configuration.nix`.
3. Evaluates the generated NixOS profile and verifies that the root and EFI
   devices match the filesystems mounted under `/mnt`.
4. Runs `nixos-install --flake ...#workstation`.
5. Sets the password for the account declared by
   `starforge.user.username` in `hosts/workstation/default.nix`.

Additional filesystems mounted below `/mnt` are included in the generated
hardware configuration. On Btrfs layouts, compression, scrubbing, and Snapper
are enabled only for applicable Btrfs mount points; a non-Btrfs root does not
receive Btrfs-only options or snapshot jobs.

This is a **single-boot** profile: it does not add a Windows entry to Limine or
chainload another operating system. The installer does not delete other EFI
partitions or modify the partition table.

### What “automatic layout detection” does not mean

Only the storage layout and detected low-level hardware configuration are
regenerated. This flake still imports the workstation's AMD CPU/GPU modules,
display topology, device rules, and other host-specific settings. Do not use
it unchanged on an unrelated PC. A different hardware platform needs its own
host profile and corresponding module review.

The generated file is changed only after the mount layout has been detected.
If validation of the generated root or EFI mount fails, the previous
`hardware-configuration.nix` is restored. Once the mounts are validated, the
new hardware configuration is retained even if `nixos-install` later fails,
so that the installation can be diagnosed and retried.

## Why this does not run on an arbitrary Linux distribution

A Git-only Ubuntu, Fedora, or other Linux installation cannot directly install
a NixOS system configuration: it does not provide the NixOS installation
environment and boot/service infrastructure. Boot the NixOS installer ISO
first. The ISO provides the required NixOS tools; Git can be provided
temporarily with `nix-shell -p git`.

See the [NixOS installation manual](https://nixos.org/manual/nixos/unstable/#sec-installation) for
the manual installation process and filesystem mounting requirements.
