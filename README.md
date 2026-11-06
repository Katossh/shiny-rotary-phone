# NixOS workstation configuration

Declarative NixOS configuration for a workstation, with reusable system modules and a separate hardware profile.

The repository manages the operating system, Niri desktop, Noctalia shell,
virtual machines, host security baseline, and user-level desktop settings.
Terminal packages and dotfiles remain integrated from
[terminal-dotfiles](https://github.com/Katossh/terminal-dotfiles).

## Repository layout

- `flake.nix`, `flake.lock`: inputs, pinned dependencies, formatter, and host profile output.
- `hosts/workstation/`: host-specific hardware, display topology, and generated hardware details.
- `modules/nixos/`: reusable system-level modules.
- `home/`: Home Manager modules for the configured workstation user.
- `.github/workflows/nixos.yml`: parallel validation and system-build checks.

## Installation

Use [`install.sh`](./install.sh) for one-command deployment. See [`INSTALL.md`](./INSTALL.md) for existing-system updates and a fresh install from the NixOS ISO. The installer validates the host profile's fixed LUKS/Btrfs/UEFI identifiers and never partitions or formats disks.

## User configuration

Personal appearance and selected desktop preferences are managed in
[`home/preferences.nix`](./home/preferences.nix). This file
provides typed options for the Noctalia theme, built-in palette, interface font,
Niri keyboard layout, layout gaps, and per-output display settings. The
workstation login name is set once as `starforge.user.username` in
`hosts/workstation/default.nix`; NixOS, Home Manager, the home directory, and
libvirt authorization derive from it. Physical monitor topology for this
workstation is configured in `hosts/workstation/displays.nix`. See
[`docs/user-configuration.md`](./docs/user-configuration.md) for defaults,
accepted values, ownership boundaries, and safe application instructions.

The repository currently supports one machine profile (`workstation`):
reusable system behavior lives in `modules/nixos/`, hardware-specific facts
live in `hosts/workstation/`, and personal preferences live in Home Manager.
Terminal configuration remains owned by `terminal-dotfiles`.

## Diagnostics and recovery

Use the following read-only commands for routine maintenance:

```sh
nixcfg doctor
nixcfg recovery
```

The existing `nixcfg status` and `nixcfg audit` commands remain available;
`nixcfg check` evaluates and builds the configuration without activating it.
See [`docs/diagnostics-recovery.md`](./docs/diagnostics-recovery.md) for
result states, exit codes, generation rollback, snapshot limitations, and
host-specific recovery guidance. See [`docs/resource-limits.md`](./docs/resource-limits.md)
for the local AI inference memory-locking limit and verification steps.

## Hardware profile

The host profile targets an AMD Ryzen 5 7600X and its integrated Radeon RDNA2
GPU on an AM5 platform.

- AMD CPU microcode and redistributable firmware are enabled.
- AMD P-State active mode is enabled for modern Ryzen power/performance scaling.
- The workstation selects `pkgs.linuxPackages_latest` in
  `hosts/workstation/hardware.nix`. This tracks the newest maintained stable
  kernel exposed by the locked Nixpkgs revision; it is not a release-candidate
  or custom kernel. The kernel-specific module set is selected with it.
- The AMDGPU kernel driver is loaded in the initrd for early KMS.
- Mesa graphics acceleration and 32-bit graphics support are enabled.
- Vulkan and VA-API diagnostic tools are installed.
- `amdgpu_top`, `lm_sensors`, `nvme-cli`, `smartmontools`, `pciutils`,
  and `usbutils` provide hardware monitoring and diagnostics.
- Clang, GCC, Rust, and Go provide the system development toolchain; jq, yt-dlp,
  and mpv provide JSON processing, media downloading, and playback.
- Bluetooth, NetworkManager, UPower, and power-profiles-daemon remain enabled.
- `fwupd` is enabled for firmware updates on devices supported by LVFS.
- `smartd` automatically monitors detected SMART-capable storage devices.
  Warnings are written to the journal and broadcast with the NixOS default
  wall notification handler.
- A monthly Btrfs scrub checks the filesystem mounted at `/`. The home, nix,
  and log subvolumes are on the same Btrfs filesystem, so they do not need
  separate scrub jobs.

Check storage health with:

```sh
sudo systemctl status smartd
sudo journalctl -u smartd
sudo btrfs scrub status /
```

A Btrfs scrub verifies checksums, but this host currently has a single NVMe
device rather than redundant Btrfs copies. It can detect corruption; it cannot
reconstruct a damaged block without a good redundant copy or backup.

Periodic discard/TRIM is not enabled for the LUKS-backed filesystem. The
current LUKS mapping does not pass discard requests through; enabling that
would be a separate encryption-policy decision because discard information
reveals allocation patterns.

All Btrfs data subvolumes (/, /home, /nix, and /var/log) use
compress=zstd:1 and noatime. Level-1 Zstandard compression is a conservative
choice that keeps CPU overhead low while compressing newly written extents.
Changing mount options does not recompress existing data; existing files are
compressed only when rewritten. autodefrag is intentionally omitted to avoid
unnecessary write amplification on a copy-on-write filesystem.

### Btrfs snapshots

Snapper maintains hourly read-only snapshots of the root and home subvolumes.
The retention limits are 6 hourly, 7 daily, 4 weekly, and 6 monthly snapshots.
The separate `/nix` and `/var/log` subvolumes are not included in the root
snapshot. Snapshots share the same physical NVMe device and are not a backup.

A small oneshot service creates `/.snapshots` and `/home/.snapshots` as
dedicated Btrfs subvolumes after local filesystems are mounted. It refuses to
replace an existing ordinary directory at either path. Snapper's timers wait
for this preparation service.

Inspect and create snapshots with:

```sh
sudo snapper -c root list
sudo snapper -c home list
sudo snapper -c home create --description "before large change"
```

Restore individual files from the corresponding
`/.snapshots/<number>/snapshot/` or
`/home/.snapshots/<number>/snapshot/` tree. Snapshots share the same physical
NVMe device and are only rollback points; this repository does not configure
an independent backup destination.

The motherboard's Wi-Fi and Bluetooth devices still depend on the exact
wireless module fitted to the board revision. Redistributable firmware and
the in-kernel drivers are enabled; verify the detected chipset with
`lspci -nnk` and `lsusb` after installation.

The host-specific CPU/GPU modules and device udev rules are isolated in
`hosts/workstation/hardware.nix`. Common hardware capabilities and diagnostic
tools remain in `modules/nixos/hardware.nix`; filesystem mount and Btrfs scrub
policy live in `modules/nixos/storage.nix`. The generated
`hosts/workstation/hardware-configuration.nix` remains untouched.

## Display configuration

The current host's Niri output preference is defined in
`hosts/workstation/displays.nix` and uses the typed
`starforge.user.desktop.monitors` option declared in Home Manager. Run
`niri msg outputs` in a Wayland session to discover connector names and
available modes. Add one attribute per display to configure its mode, scale,
and optional logical position. See
[`docs/user-configuration.md`](./docs/user-configuration.md) for examples.


## Bootloader and Windows dual boot

The workstation profile uses Limine in UEFI mode. Limine is selected here because it supports
direct EFI chainloading from another partition by GPT partition GUID, allowing
Windows Boot Manager to remain on its own EFI partition without relying on an
unsigned UEFI Shell intermediary.

The current disk layout is intentionally preserved:

- NixOS keeps using the existing 1 GB FAT32 `/boot` partition
  (currently `/dev/nvme0n1p5`, filesystem UUID `FD77-5C81`).
- Windows keeps its existing 200 MB EFI System Partition
  (`/dev/nvme0n1p1`).
- The Windows entry targets the Windows ESP by its GPT partition GUID:
  `68a6f3c1-1eee-4845-8c3e-7108cec34c4a`, loading
  `/EFI/Microsoft/Boot/bootmgfw.efi`.

The NixOS `/boot` partition is FAT32 and is already used by a working UEFI
boot entry, although its GPT type is currently reported as `Linux filesystem`
rather than `EFI System`. This configuration deliberately does not rewrite
the partition table or create another Windows-visible EFI System Partition.
Do not change its GPT type or resize either EFI-related partition as part of
this bootloader migration.

Limine is configured for Secure Boot signing with the locally provisioned
`sbctl` database key. Key creation and enrollment remain manual workstation
operations; the NixOS configuration signs the Limine EFI executable during
bootloader installation but does not generate or enroll keys automatically.

Secure Boot is enabled on the workstation and both `sbctl status` and
`bootctl status` report it active in User Mode. The enrollment retained the
Microsoft and firmware-builtin certificates so Windows Boot Manager remains
chainloadable through Limine. The MSI firmware is configured for Custom mode
and the Maximum Security preset.

**Firmware caveat:** `sbctl` still reports MSI quirk FQ0001, which warns that
the firmware may execute EFI images despite a Secure Boot policy violation.
The Maximum Security preset is selected, but the persistent warning means
fail-closed enforcement should not be assumed solely from the Secure Boot
status. Keep the known-good recovery route and do not delete the existing
`dbx` revocation database.

The workstation profile does not configure Windows volume encryption.

## Memory and session protection

- Zram swap uses Zstandard and has a maximum logical capacity of 50% of physical
  RAM. This is a capacity limit, not a permanently reserved 16 GB allocation
  on this 32 GB host.
- systemd-oomd monitors machine.slice with a 75% memory-pressure limit held
  for 30 seconds. User slices are deliberately excluded, so OOMD does not
  target the interactive desktop session. If pressure remains high, an eligible
  VM cgroup can be terminated to preserve host responsiveness. This is an
  emergency kill, not a guest ACPI shutdown; avoid overcommitting VM memory
  when guest data is important.
- Noctalia locks the session after 10 minutes of inactivity and powers displays
  off after 15 minutes. It locks before suspend and has no passwordless
  post-lock grace period. Active idle inhibitors, such as video playback, are
  respected.
- Hibernation, hybrid sleep, and suspend-then-hibernate are disabled because
  this host currently has zram only and no persistent swap/resume target.
  Suspend-to-RAM remains available. Add and test persistent swap before
  considering hibernation.

Useful checks: `zramctl`, `swapon --show`, `systemctl status systemd-oomd`,
`oomctl`, `systemd-cgls /machine.slice`, and
`systemctl show machine.slice -p ManagedOOMMemoryPressure -p ManagedOOMMemoryPressureLimit -p ManagedOOMMemoryPressureDurationSec`.

## Virtualisation

The host uses AMD KVM with QEMU and libvirt:

- `kvm-amd` is retained in the generated hardware configuration.
- `virtualisation.libvirtd` provides the system VM daemon.
- QEMU guests run as the dedicated unprivileged `qemu-libvirtd` account.
- `swtpm` is enabled for virtual TPM 2.0 devices, useful for Windows 11 guests.
- OVMF/UEFI firmware is supplied by the QEMU/libvirt module.
- Virt-manager provides the graphical manager.
- SPICE USB redirection is enabled.
- virtiofsd is installed as a vhost-user backend, enabling VirtioFS host-directory sharing in VM definitions.
- The short-lived `libvirtd-config` and `libvirt-default-network` helper units use a shared systemd sandbox: no new privileges, private home/tmp/device views, read-only `/usr`/`/boot`/`/efi`, UNIX-socket-only access, and restrictions on kernel interfaces, namespaces, realtime scheduling, SUID/SGID creation, and writable-executable memory. The long-running `libvirtd` daemon is deliberately not given this blanket profile because it must manage KVM devices, cgroups, and virtual networking.
- Host shutdown requests a guest ACPI shutdown rather than saving guest RAM state; up to two guests are asked to stop concurrently.
- Libvirt management is granted through Polkit to the active local
  configured local user session; the user no longer needs broad `libvirtd` group membership.

Before creating VMs, enable CPU virtualisation (SVM) in the motherboard UEFI.
IOMMU is only needed for device passthrough; it is not required for ordinary
KVM guests. GPU passthrough is deliberately not configured because the
integrated GPU is also driving the host desktop.

The default libvirt NAT network is configured to start automatically
after libvirtd on each boot. The libvirtd service receives `dnsmasq` in its
runtime PATH for DHCP and DNS on that network. The bridge remains subject to
the host firewall; it is not added to `trustedInterfaces`.

Useful checks:

```sh
ls -l /dev/kvm
virsh -c qemu:///system list --all
virsh -c qemu:///system net-list --all
cat /sys/module/kvm_amd/parameters/nested
systemctl status libvirt-default-network.service
systemd-analyze security libvirtd-config.service libvirt-default-network.service
```

Because QEMU runs unprivileged, direct USB/PCI device assignment may require
additional per-device permissions. Do not solve that by running all QEMU
processes as root; add narrowly scoped access for the specific device instead.

### AMD IOMMU

The host is prepared for AMD IOMMU-backed PCI device passthrough. Enable
**IOMMU / AMD-Vi** in the motherboard UEFI. This is separate from **SVM**,
which enables CPU virtualization for KVM.

The current upstream AMD IOMMU driver detects the hardware through the ACPI
IVRS table and initializes when firmware exposes it. No extra
`amd_iommu=on` argument is added: the current upstream kernel parameter list
does not define `on` as a valid value for `amd_iommu=`. Do not use
`amd_iommu=force_enable` to bypass firmware or platform detection.

No PCI device is bound to VFIO, no device IDs are reserved, and no GPU is
detached from the host. This is deliberate: the Radeon iGPU currently drives
the desktop, and there is no dedicated device selected for passthrough. Do
not add `vfio-pci.ids` or early VFIO module binding until a specific device
and its complete IOMMU group have been identified.

After enabling the UEFI setting, reboot and inspect IOMMU initialization and
device groups:

```sh
sudo dmesg | grep -Ei 'AMD-Vi|IOMMU'
find /sys/kernel/iommu_groups/ -type l | sort
lspci -nnk
```

An IOMMU group is the practical isolation unit for PCI passthrough: inspect all
devices in the target group before assigning any of them to a guest. A usable
IOMMU group does not by itself mean that a device is safe to detach from the
host. Keep the integrated GPU and any devices needed for boot, storage,
networking, or input on the host.

The configuration does not set `iommu=pt` or force isolation overrides.
Those options change DMA mapping behavior and should be selected only after
the actual passthrough workload and hardware topology are known.

## Containers

Podman is the host's OCI container runtime; Docker Engine is not enabled.

- Podman is daemonless and intended to be used rootless by the configured workstation user.
- NixOS allocates a subordinate UID/GID range for the user so rootless
  containers and Distrobox can create user namespaces.
- `docker` is provided as a CLI alias for Podman to ease migration of existing
  Docker-oriented commands. This does **not** enable the Docker-compatible API
  socket. The rootful Podman socket is not exposed to the user.
- The default Podman bridge has DNS enabled for Compose workloads.
- Home Manager installs Distrobox for user-managed development environments
  and `podman-compose` as the explicitly selected external provider for
  `podman compose`. Distrobox is explicitly pinned to the Podman backend.

Prefer rootless commands without `sudo`:

```sh
podman info
podman run --rm quay.io/podman/hello
podman-compose version
distrobox create --name fedora-dev --image registry.fedoraproject.org/fedora:latest
distrobox enter fedora-dev
distrobox list
```

Distrobox environments are user containers, not virtual machines: they share
the host kernel and integrate with the user's home directory and desktop.
Use the existing KVM/libvirt stack when stronger isolation or a separate
kernel is required. Container images and writable layers are stored in the
user's Podman…