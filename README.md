# NixOS workstation configuration

Declarative NixOS configuration for a workstation, with reusable system modules and a separate hardware profile.

The repository manages the operating system, Niri desktop, Noctalia shell,
virtual machines, host security baseline, and user-level desktop settings.
Terminal packages and dotfiles remain integrated from
[terminal-dotfiles](https://github.com/Katossh/terminal-dotfiles).

## Repository layout

- `flake.nix`, `flake.lock`: inputs, pinned dependencies, formatter, and host profile output.
- `hosts/workstation/`: host-specific configuration and generated hardware details.
- `modules/nixos/`: reusable system-level modules.
- `home/katossh/`: Home Manager configuration for the user.
- `.github/workflows/nixos.yml`: parallel validation and system-build checks.

## Installation

Use [`install.sh`](./install.sh) for one-command deployment. See [`INSTALL.md`](./INSTALL.md) for existing-system updates and a fresh install from the NixOS ISO. The installer validates the host profile's fixed LUKS/Btrfs/UEFI identifiers and never partitions or formats disks.

## User configuration

Personal appearance and selected desktop preferences are managed in
[`home/katossh/preferences.nix`](./home/katossh/preferences.nix). This file
provides typed options for the Noctalia theme, built-in palette, interface font,
Niri keyboard layout, and layout gaps. See
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
host-specific recovery guidance.

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

- Podman is daemonless and intended to be used rootless as `katossh`.
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
user's Podman storage, outside the Nix store.

The NixOS Podman module provides a rootless per-user API socket at
`$XDG_RUNTIME_DIR/podman/podman.sock`; it is scoped to this user's containers.
The Docker-compatible system-wide `/run/docker.sock` alias is not enabled,
and the user is not added to the rootful `podman` group. When an application
needs the Docker API, point it at the rootless socket with
`DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock` rather than granting
it access to the rootful socket.

After the first switch that adds the subordinate ID mapping, log out and back
in before creating rootless containers. Verify the mapping and runtime with:

```sh
grep "^katossh:" /etc/subuid /etc/subgid
podman info --debug
```

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
- AppArmor enforces the existing `curl` profile and loads separate
  complain-mode profiles for Firefox, Chromium, VS Code, and Zed. The browser
  profiles explicitly deny direct access to selected credential stores; the
  editor profiles remain observational while their child-process workflows
  are reviewed.
- USBGuard runs with a default-allow policy. It preserves devices already
  connected at daemon startup, evaluates newly inserted devices against its
  rule file, and allows unmatched devices. It is an audit/selective-control
  layer here, not a USB allowlist or a guarantee against spoofed BadUSB devices.
  Only root can use its IPC interface; the D-Bus interface is disabled.
- Secure Boot is enabled and Limine is signed with the locally enrolled
  `sbctl` database key. MSI firmware quirk FQ0001 remains reported by
  `sbctl`; see the Secure Boot caveat above.
- The Linux root and Btrfs data subvolumes remain inside the existing LUKS
  container. TPM-backed unlocking is not configured yet.

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

### P0 security audit

Run `nixcfg audit` to collect read-only diagnostics for Secure Boot,
AppArmor, USBGuard, CPU mitigations, AMD P-State, sysctl hardening, and AMD
IOMMU. The command does not modify system state. See
[`docs/security-audit.md`](./docs/security-audit.md) for the review procedure
and the safety gates before tightening any policy.

### AppArmor

AppArmor is enabled through the NixOS module. It activates the AppArmor LSM,
loads declared policies at boot, and provides the management utilities. A
reboot is required the first time this LSM is enabled.

The Nixpkgs `curl` executable runs under an **enforced** profile. It can
read the immutable Nix store, use DNS and ordinary IPv4/IPv6 TCP/UDP networking,
and read or write files in the invoking user's home directory. It is explicitly
denied access to `.ssh`, `.gnupg`, `.aws`, GitHub CLI credentials, and
Google Cloud credentials. Writes outside the home and temporary directories
are denied by default.

Separate profiles are also loaded for:

- **Firefox and Chromium:** `complain` mode, with access to their own browser
  state/cache and Downloads explicitly allowed. Direct reads and writes to
  selected developer credential stores (`.ssh`, `.gnupg`, `.aws`,
  `.config/gh`, `.config/gcloud`, `.kube`, Docker config, SOPS age keys,
  and `.password-store`) are explicitly denied. Explicit `deny` rules remain
  effective even in complain mode; other unlisted operations are logged but
  allowed.
- **VS Code and Zed:** `complain` mode with no hard-coded credential denies.
  These editors launch terminals, language servers, build scripts, Git/SSH and
  extensions, so their actual process trees must be reviewed before introducing
  enforcing restrictions.

The desktop profiles are a staging baseline, not full application confinement:
complain mode does not block ordinary unmatched operations. In particular,
the editor profiles currently provide telemetry rather than a security boundary.
Do not promote them to `enforce` until the observed accesses and normal
workflows have been reviewed.

After deploying, verify the loaded profiles and inspect AppArmor events:

```sh
sudo aa-status
sudo systemctl status apparmor.service
sudo journalctl -k -b --grep='apparmor="ALLOWED"'
sudo journalctl -k -b --grep='apparmor="DENIED"'
```

The existing `curl` profile deliberately protects credential directories even
though it allows other home-directory files. Do not add exceptions for those
paths just to silence denials; review the affected command and adjust only
when access is genuinely required. `killUnconfinedConfinables` remains
disabled so profile changes do not terminate already-running desktop processes.

### USBGuard

USBGuard is enabled with a **permissive default-allow policy**, not a device
allowlist. Existing devices retain their current authorization state when the
daemon starts. Newly inserted devices are evaluated against the mutable
`/var/lib/usbguard/rules.conf`; when no rule matches, the default policy allows
the device. No D-Bus interface is enabled, and only root is allowed to use the
USBGuard IPC interface.

This provides device inventory, event visibility, and the option to add
specific manual rules without automatically blocking unknown keyboards,
mice, storage devices, or other peripherals. USB descriptors can be spoofed,
so this policy is not a guarantee against BadUSB.

Useful commands:

```sh
sudo usbguard list-devices
sudo usbguard list-rules
sudo usbguard watch
sudo journalctl -u usbguard -b
```

## Desktop

- Niri is enabled at the NixOS level so greetd can launch the session.
- Home Manager owns and validates the generated Niri KDL configuration.
- Noctalia is configured through its Home Manager module and validates its TOML.
- Noctalia uses the Catppuccin built-in palette and Inter as its system-installed interface font.
- LocalSend is installed for cross-platform LAN file sharing.
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
2. **Build workstation system** builds the full
   `nixosConfigurations.workstation.config.system.build.toplevel` closure.
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
to require both `Validate Nix configuration` and `Build workstation system`
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
`hosts/workstation/hardware-configuration.nix`, which is owned by
`nixos-generate-config` and is still evaluated by the flake checks and full
system build. Run them locally before opening a PR:

```sh
mapfile -t nix_files < <(git ls-files "*.nix" ":!:hosts/workstation/hardware-configuration.nix")
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
mapfile -t nix_files < <(git ls-files "*.nix" ":!:hosts/workstation/hardware-configuration.nix")
nix fmt -- "${nix_files[@]}"
nix flake check --no-build --no-update-lock-file --show-trace
nix build .#nixosConfigurations.workstation.config.system.build.toplevel --no-link
```

The Niri Home Manager module validates generated KDL, and the Noctalia module
validates generated settings during the build.

## Apply safely

First build the new system, then activate it as a test:

```sh
sudo nixos-rebuild build --flake .#workstation
sudo nixos-rebuild test --flake .#workstation
```

Check the Niri session, Noctalia shell, networking, Bluetooth, audio, portals,
screenshots, media keys, display controls, Vulkan/VA-API, sensors, and a test VM.
Only after those checks pass, make the generation the default:

```sh
sudo nixos-rebuild switch --flake .#workstation
```

Keep the previous generation available in the firmware boot menu. To roll back
from a running system, use:

```sh
sudo nixos-rebuild switch --rollback
```

The generated hardware configuration contains the host's disk UUIDs and mount
layout. It is preserved under `hosts/workstation/` and must not be copied to a
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
- Keep a known-good recovery route available before modifying bootloader
  or Secure Boot settings. The Limine menu retains up to five NixOS generations;
  verify the active Limine and Windows chainloading paths on the host before
  relying on them as the only recovery route.
