# Starforge NixOS configuration

Declarative NixOS configuration for the `starforge` workstation.

The repository manages the operating system, Niri desktop, Noctalia shell,
virtual machines, host security baseline, and user-level desktop settings.
Terminal packages and dotfiles remain integrated from
[terminal-dotfiles](https://github.com/Katossh/terminal-dotfiles).

## Repository layout

- `flake.nix`, `flake.lock`: inputs, pinned dependencies, formatter, and host output.
- `hosts/starforge/`: machine-specific configuration and generated hardware details.
- `modules/nixos/`: reusable system-level modules.
- `home/katossh/`: Home Manager configuration for the user.
- `.github/workflows/nixos.yml`: parallel validation and system-build checks.

## Installation

Use [`install.sh`](./install.sh) for one-command deployment. See [`INSTALL.md`](./INSTALL.md) for existing-system updates and a fresh install from the NixOS ISO. The script validates Starforge's fixed LUKS/Btrfs/UEFI identifiers and never partitions or formats disks.

## Hardware profile

The host profile targets an AMD Ryzen 5 7600X and its integrated Radeon RDNA2
GPU on an AM5 platform.

- AMD CPU microcode and redistributable firmware are enabled.
- AMD P-State active mode is enabled for modern Ryzen power/performance scaling.
- The host uses pkgs.linuxPackages, Nixpkgs' default supported LTS kernel set, rather than the newest mainline kernel alias.
- The AMDGPU kernel driver is loaded in the initrd for early KMS.
- Mesa graphics acceleration and 32-bit graphics support are enabled.
- Vulkan and VA-API diagnostic tools are installed.
- `amdgpu_top`, `lm_sensors`, `nvme-cli`, `smartmontools`, `pciutils`,
  and `usbutils` provide hardware monitoring and diagnostics.
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

## Bootloader and Windows dual boot

Starforge uses Limine in UEFI mode. Limine is selected here because it supports
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

The Limine boot path is being kept separate from Secure Boot for now.
Boot both NixOS and Windows through Limine with firmware Secure Boot disabled,
and retain the existing `NixOS-boot` GRUB entry as a recovery route. Do not
rewrite the partition table, resize either EFI-related partition, or delete
the old GRUB files during this process.

### Secure Boot (deferred)

Secure Boot signing and enforcement are **not enabled** in the NixOS
configuration. No Secure Boot keys are generated or enrolled by this
repository, and no firmware settings should be changed as part of this
configuration update. The Limine EFI boot path remains in its current
non-Secure-Boot state.

This can be revisited after the Limine/Windows chainload path has been tested
on the workstation and a recovery procedure has been confirmed. The existing
LUKS/Btrfs arrangement is unchanged.

Starforge does not configure Windows volume encryption.

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
- Host shutdown requests a guest ACPI shutdown rather than saving guest RAM state; up to two guests are asked to stop concurrently.
- Libvirt management is granted through Polkit to the active local
  `katossh` session; the user no longer needs broad `libvirtd` group membership.

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

## Security baseline

- The NixOS firewall is explicitly enabled, with no extra inbound TCP or UDP
  ports opened.
- The OpenSSH server is explicitly disabled; this machine does not accept
  inbound SSH sessions. This does not prevent outbound SSH when a client is installed.
- The existing iptables-based firewall backend is retained for compatibility
  with libvirt networking; nftables can be evaluated separately.
- Kernel image protection is enabled.
- Auditd records privileged command execution for both 64-bit and 32-bit
  processes.
- Kernel pointer and dmesg exposure are restricted; ptrace is limited to the
  normal parent/child model; unprivileged BPF is disabled.
- Filesystem protections for symlinks, hardlinks, FIFOs, and regular files
  are explicitly enabled.
- IPv4/IPv6 redirect acceptance and IPv4 source routing are disabled.
- Sudo requires a password, forces a pseudo-terminal, limits password retries
  to three, and limits credential caching to five minutes.
- Nix builds remain sandboxed; only root and wheel members may use the daemon,
  while only root is a trusted Nix user.
- USBGuard allows IPC control only to root, preserves currently connected
  devices during startup, and allows newly inserted devices unless an explicit
  local rule blocks them.
- AppArmor enforces a dedicated profile for the system `curl` executable;
  browsers and other desktop applications are not yet confined.
- Secure Boot is deferred. No keys are generated or enrolled, and the
  firmware enforcement state is left untouched.
- Existing LUKS full-disk encryption and encrypted Btrfs layout are preserved.

This is a workstation baseline, not a claim of complete isolation. The
Noctalia session is configured to lock after ten minutes of inactivity, turn
the displays off after fifteen minutes, and lock before suspend.
TPM-backed LUKS unlocking remains a separate, not-yet-provisioned stage:
the passphrase path is retained until PCR policy and recovery are tested.
IOMMU is
enabled as a base facility, but actual PCI passthrough remains unconfigured
until a suitable device and its complete IOMMU group are reviewed. Kernel
module locking remains intentionally omitted because this workstation needs
runtime hardware, networking, Bluetooth, and KVM modules.

### AppArmor

AppArmor is enabled through the NixOS module. It activates the AppArmor LSM,
loads declared policies at boot, and provides the management utilities. A
reboot is required the first time this LSM is enabled.

The Nixpkgs `curl` executable now runs under an **enforced** profile. It can
read the immutable Nix store, use DNS and ordinary IPv4/IPv6 TCP/UDP networking,
and read or write files in the invoking user's home directory. It is explicitly
denied access to the contents of `.ssh`, `.gnupg`, `.aws`, GitHub CLI
credentials, and Google Cloud credentials. Writes outside the home and
temporary directories are denied by default. This is a targeted profile, not
a claim that the browser, editor, or every desktop process is confined.

After deploying and rebooting, verify the loaded profile and exercise normal
curl operations:

```sh
sudo aa-status
sudo systemctl status apparmor.service
readlink -f "$(command -v curl)"
curl -I https://example.com
curl -o "$HOME/Downloads/apparmor-test.txt" https://example.com
```

Check for denied operations:

```sh
sudo journalctl -k -b --grep='apparmor="DENIED"'
```

The profile deliberately protects credential directories even though it
allows other home-directory files. Do not add exceptions for those paths just
to silence denials; review the affected command and adjust only when the
access is genuinely required. `killUnconfinedConfinables` remains disabled so
profile changes do not send signals to already-running desktop processes.
### USBGuard device management

USBGuard starts after the initial udev device enumeration has settled.
Its policy is deliberately permissive for ordinary workstation use:

- Devices already connected when USBGuard starts keep their current state.
- Newly inserted devices are evaluated against the local rule file.
- Devices without an explicit matching rule are allowed by default.
- Explicit local block rules continue to deny matching devices.
- Only root can use the USBGuard IPC interface.

Inspect the current device and rule state with:

```sh
sudo usbguard list-devices --tree
sudo usbguard list-devices --blocked
sudo usbguard list-rules
sudo journalctl -u usbguard -b
```

Persistent rules remain host-local in `/var/lib/usbguard/rules.conf` and are
not committed to Git because they contain hardware-specific identifiers.
There is no generated host-specific allowlist and devices connected at boot
are not re-authorized by a strict startup policy.

## Desktop

- Niri is enabled at the NixOS level so greetd can launch the session.
- Home Manager owns and validates the generated Niri KDL configuration.
- Noctalia is configured through its Home Manager module and validates its TOML.
- Noctalia uses the Catppuccin built-in palette and JetBrainsMono Nerd Font.
- The session locks after ten idle minutes, turns displays off after fifteen,
  and locks before suspend with no passwordless grace period.
- Kitty and Zsh configuration remain owned by terminal-dotfiles to avoid
  competing Home Manager definitions.

Noctalia is pinned to its `cachix` branch. Its Nixpkgs input deliberately does
not follow the root Nixpkgs input: this preserves derivation compatibility
with the Noctalia Cachix binary cache. The nested Nixpkgs revision is pinned
in `flake.lock`.

## CI and build caching

GitHub Actions runs two independent jobs in parallel:

1. **Validate Nix configuration** formats maintained Nix files, runs
   `statix` and `deadnix` using the flake's pinned development shell, and
   evaluates flake outputs with `nix flake check --no-build`. This is the
   quick feedback path; it does not compile the complete operating system.
2. **Build Starforge system** builds the full
   `nixosConfigurations.starforge.config.system.build.toplevel` closure.
   This remains the expensive integration check.

Both jobs use the committed `flake.lock`; normal CI does not update
dependencies. The full build uses Nix's `--fallback` option so a temporary
binary-cache transfer failure can fall back to building an unavailable
substitute from source. It can also use a public Cachix binary cache to reuse
store paths between runs. Pull requests receive read-only cache access. Only
pushes to `main` receive the cache write token and can publish build results.

### Enable the Starforge Cachix cache

Cachix is optional until configured. To enable it:

1. Create a **public** cache named `starforge` at
   [app.cachix.org](https://app.cachix.org/).
2. In the repository, open **Settings → Secrets and variables → Actions**.
3. Add a repository variable named `CACHIX_CACHE_NAME` with value `starforge`.
4. In the same settings page, add a repository secret named
   `CACHIX_AUTH_TOKEN` using a per-cache token with write access to that cache.
   Cachix manages signing keys for managed caches; no separate signing key is
   required.

When the cache-name variable is absent, the workflow skips Cachix and still
builds normally using the configured Nix substituters. Pull-request workflows
never receive or use the write token; they use the public cache in read-only
mode. On pushes to `main`, the workflow checks whether the write token exists
before enabling publishing. If the secret is missing, it emits a warning and
continues with read-only cache access instead of failing the build. The cache
must be public for token-free reads from pull requests.

The cache name is not a secret. Keep `CACHIX_AUTH_TOKEN` only in GitHub
Actions secrets; never commit it to the repository or place it in the Nix
store. Use a per-cache token limited to write access for the `starforge`
cache.

The first trusted build on `main` populates the cache. Subsequent CI runs can
download matching store paths rather than rebuilding them. A changed input,
compiler, or derivation may still require new builds.

To let the workstation consume the same public cache, install the Cachix CLI
and run:

```sh
cachix use starforge
```

Review the generated Nix configuration before applying it declaratively to
the host.

The jobs are separate checks. Configure the repository ruleset for `main`
to require both `Validate Nix configuration` and `Build Starforge system`
before merging. Review approvals can remain at zero if solo maintenance is
preferred; required checks and required reviews are separate controls.

GitHub Actions dependencies are checked weekly by Dependabot. A separate
weekly workflow runs `nix flake update`, opens or refreshes a reviewable PR,
and manually dispatches the NixOS validation/build workflow for that branch.
It never merges updates automatically.

CI never activates a NixOS generation or deploys to the workstation.

## Static analysis

The flake provides a development shell with `statix` and `deadnix` from the
locked Nixpkgs revision. Formatting and static analysis cover maintained Nix
files and deliberately exclude the NixOS-generated
`hosts/starforge/hardware-configuration.nix`, which is owned by
`nixos-generate-config` and is still evaluated by the flake checks and full
system build. Run them locally before opening a PR:

```sh
mapfile -t nix_files < <(git ls-files "*.nix" ":!:hosts/starforge/hardware-configuration.nix")
nix fmt -- "${nix_files[@]}"
nix develop
for nix_file in "${nix_files[@]}"; do
  statix check "$nix_file"
done
deadnix --fail "${nix_files[@]}"
```

## Validate and build locally

Run these commands from the repository root:

```sh
mapfile -t nix_files < <(git ls-files "*.nix" ":!:hosts/starforge/hardware-configuration.nix")
nix fmt -- "${nix_files[@]}"
nix flake check --no-build --no-update-lock-file --show-trace
nix build .#nixosConfigurations.starforge.config.system.build.toplevel --no-link
```

The Niri Home Manager module validates generated KDL, and the Noctalia module
validates generated settings during the build.

## Apply safely

First build the new system, then activate it as a test:

```sh
sudo nixos-rebuild build --flake .#starforge
sudo nixos-rebuild test --flake .#starforge
```

Check the Niri session, Noctalia shell, networking, Bluetooth, audio, portals,
screenshots, media keys, display controls, Vulkan/VA-API, sensors, and a test VM.
Only after those checks pass, make the generation the default:

```sh
sudo nixos-rebuild switch --flake .#starforge
```

Keep the previous generation available in the firmware boot menu. To roll back
from a running system, use:

```sh
sudo nixos-rebuild switch --rollback
```

The generated hardware configuration contains the host's disk UUIDs and mount
layout. It is preserved under `hosts/starforge/` and must not be copied to a
different machine without regenerating it.

## Updating dependencies

Inputs are pinned by `flake.lock`. Review updates rather than tracking moving
branches at every rebuild:

```sh
nix flake update
git diff -- flake.lock
nix fmt
nix flake check --no-build --no-update-lock-file --show-trace
```

Review Nixpkgs, Home Manager, Noctalia, and terminal-dotfiles changes before
applying them to the host. Do not change `system.stateVersion` merely to
follow a newer NixOS release; it remains `26.05` from the original install.

## Maintenance and recovery

- Garbage collection runs weekly and removes unreferenced store paths older
  than 14 days. Existing system generations are not automatically deleted.
- Store optimisation runs weekly.
- GitHub Actions validates formatting and evaluates the flake in a lightweight
  job, then builds the complete system closure in a separate job.
- Keep a known-good generation and a copy of the hardware configuration
  before changing bootloader, LUKS, Btrfs, or kernel settings.
- Keep the previous GRUB UEFI boot entry until Limine and Windows chainloading
  have passed real reboot tests. Secure Boot is not part of this rollout.
