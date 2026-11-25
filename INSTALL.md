# Installing the NixOS configuration

\`install.sh\` applies the workstation NixOS flake from either an installed
NixOS system or the official NixOS installer environment.

> **Hardware scope:** this remains a workstation profile for the current AMD
> Ryzen 7000 desktop (not a universal configuration for every computer). The
> installer adapts to different storage layouts: root can be Btrfs, ext4, or
> XFS; the UEFI System Partition must be FAT32 and mounted at \`/mnt/boot\`.
> Separate \`/home\`, \`/nix\`, and \`/var/log\` mounts are optional. \`nixos-generate-config\`,
> not \`install.sh\`, discovers filesystem UUIDs, device names, Btrfs subvolumes,
> and open LUKS mappings from the actual mount tree. Review that generated file
> before installation.

The script never partitions disks, formats filesystems, creates Btrfs
subvolumes, changes LUKS keys, or enrolls Secure Boot keys.

Before evaluating the flake, the installer refreshes the machine-specific
hosts/workstation/hardware-configuration.nix. On an existing NixOS system it
copies /etc/nixos/hardware-configuration.nix when that file exists, otherwise
it runs nixos-generate-config on the running system. On a fresh installation it
generates the file from the filesystems mounted under /mnt. It validates the
candidate first and preserves a changed existing repository copy as
hardware-configuration.nix.bak (later backups receive timestamps) before
replacing it.

The file is no longer ignored by Git. It can be committed with the host
configuration, but it contains filesystem UUIDs, device paths, and mount
topology. This repository is public: committing the file publishes those
machine-specific identifiers. They are not encryption keys or passwords, but
use a private repository or keep the file out of commits if you do not want
that information public. install.sh does not stage it automatically because
the installer runs as root; review and stage it as your normal user.

The script never partitions disks, formats filesystems, creates Btrfs
subvolumes, changes LUKS keys, or enrolls Secure Boot keys. For an encrypted
fresh-install root, open the LUKS container before mounting it so
nixos-generate-config can detect the mapping.


## Machine-local hardware configuration

The installer refreshes
`hosts/workstation/hardware-configuration.nix` before evaluating the
workstation profile.

For an existing NixOS installation, it copies
`/etc/nixos/hardware-configuration.nix` when available. If that file does not
exist, it runs:

~~~sh
sudo nixos-generate-config --show-hardware-config
~~~

For a fresh installation, it runs the equivalent command against the mounted
target:

~~~sh
sudo nixos-generate-config --root /mnt --show-hardware-config
~~~

The installer writes the output to a temporary file, verifies that it parses
and contains root and `/boot` filesystem declarations, and only then replaces
the repository copy. If the contents differ, the old copy is preserved as
`hardware-configuration.nix.bak`; if that backup already exists, a
timestamped `.bak` file is created instead. If the candidate is invalid or
generation fails, the existing file is left untouched. If the content is
already identical, no backup is created.

The file is trackable in Git. After reviewing it, stage it as your normal
user:

~~~sh
git diff -- hosts/workstation/hardware-configuration.nix
git add hosts/workstation/hardware-configuration.nix
git commit -m "chore: track workstation hardware configuration"
~~~

**Privacy:** this repository is public. Committing the generated file publishes
filesystem UUIDs, device paths, and mount layout. Those values are not
credentials, but they disclose details about the machine and storage. Keep the
repository private or do not commit the file if that disclosure is unwanted.
Backup files remain Git-ignored.

## Existing NixOS installation

From the running NixOS system:

~~~sh
git clone https://github.com/Katossh/shiny-rotary-phone.git ~/nixos-config
cd ~/nixos-config
sudo ./install.sh
~~~

The script runs \`nixos-rebuild switch\` against the local flake directory.
It uses a \`path:\` flake reference so the Git-ignored hardware configuration
is included during evaluation. Nix evaluates and builds the new generation
before activating it. The existing \`flake.lock\` is used; dependencies are not
deliberately updated as part of installation.

For a temporary activation that does not change the default boot generation:

~~~sh
sudo ./install.sh --test
~~~

After testing the desktop, networking, audio, Bluetooth, boot menu, and other
hardware, make the configuration permanent with:

~~~sh
sudo ./install.sh --switch
~~~

To update the repository and apply reviewed changes:

~~~sh
git pull --ff-only
sudo ./install.sh
~~~

## Fresh single-boot installation from the NixOS ISO

1. Boot the official NixOS x86_64 installer in **UEFI mode** and connect to the
   network.
2. Partition and format the disk yourself. Create a FAT32 EFI System Partition
   and a root filesystem using Btrfs, ext4, or XFS. If the root is encrypted,
   open the LUKS container before mounting it.
3. Mount the root filesystem at \`/mnt\`, the EFI partition at \`/mnt/boot\`,
   and any separate filesystems/subvolumes at their final mount points. For
   example, with an encrypted Btrfs filesystem and subvolumes named \`@\`,
   \`@home\`, \`@nix\`, and \`@log\`:

~~~sh
sudo -i
cryptsetup open /dev/nvme0n1p2 cryptroot

mount -o subvol=@ /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{boot,home,nix,var/log,etc/nixos}
mount -o subvol=@home /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log /dev/mapper/cryptroot /mnt/var/log
mount /dev/nvme0n1p1 /mnt/boot
~~~

Replace the example device paths and subvolume names with the actual layout.
For a simpler Btrfs, ext4, or XFS layout, mount only the root filesystem and
ESP; the profile keeps \`/home\`, \`/nix\`, and \`/var/log\` inside the root
filesystem. \`nixos-generate-config\` records every additional filesystem mounted
below \`/mnt\` in the generated hardware configuration; \`install.sh\` only
validates that the existing file is present, contains root and \`/boot\`
entries, and parses as Nix.

For Btrfs, Snapper is enabled only for mountpoints that the generated hardware
configuration identifies as separate Btrfs subvolumes. It is disabled when
the layout contains no suitable Btrfs subvolume, so an ext4 or XFS root does
not receive invalid Btrfs snapshot services.

4. Clone this repository into the target root and run the installer:

~~~sh
git clone https://github.com/Katossh/shiny-rotary-phone.git /mnt/etc/nixos
cd /mnt/etc/nixos
./install.sh

# Explicit equivalent:
# ./install.sh --install
~~~

With no mode specified, install.sh detects the clone at /mnt/etc/nixos
and selects fresh-install mode. It verifies the supported root filesystem,
the FAT32 ESP at /mnt/boot, and UEFI boot. Before evaluation, it generates
hosts/workstation/hardware-configuration.nix from the filesystems mounted
under /mnt and validates the result. Any previous repository copy is backed
up before replacement. The file is Git-trackable; review the privacy warning
above before committing it to this public repository. It does not need a
Windows ESP or any Windows partition. The boot menu is configured for NixOS
single boot.

After \`nixos-install\` completes, the script prompts you to set the password
for the account configured by \`starforge.user.username\` in
\`hosts/workstation/default.nix\` (currently \`katossh\`). Set the root password
during the installation when prompted.

### Secure Boot keys

This profile enables Limine Secure Boot signing. The signing keys are not
stored in Git and must exist at \`/var/lib/sbctl/keys\` in the target system.
If the old root filesystem was erased, restore the backed-up \`/var/lib/sbctl\`
directory to \`/mnt/var/lib/sbctl\` before installing. Disabling Secure Boot in
firmware does not preserve or recreate deleted signing keys. The installer
warns if the keys are missing; the bootloader installation may fail until
they are restored or Secure Boot signing is temporarily disabled in
\`modules/nixos/boot.nix\`.

## Scope and limitations

The installer discovers and refreshes the machine-local hardware configuration
from the running system or mounted installation target. It does not
automatically partition disks, format filesystems, create subvolumes, or decide
which disk to erase. The workstation profile itself
still contains hardware-specific AMD GPU, CPU, display, and peripheral
settings. A different computer needs a separately reviewed hardware profile.

A Git-only Ubuntu, Fedora, or other Linux installation cannot directly
activate a NixOS system configuration. Boot the NixOS installer ISO first.

See the [NixOS installation manual](https://nixos.org/manual/nixos/stable/#sec-installation)
for preparing and mounting target filesystems and installing a flake.
