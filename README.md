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

## Hardware profile

The host profile targets an AMD Ryzen 5 7600X and its integrated Radeon RDNA2
GPU on an AM5 platform.

- AMD CPU microcode and redistributable firmware are enabled.
- AMD P-State active mode is enabled for modern Ryzen power/performance scaling.
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

The initial Limine migration does **not** enable Secure Boot. First verify that
both NixOS and Windows boot from the Limine menu, while keeping the existing
`NixOS-boot` GRUB firmware entry as a fallback. Do not delete the old GRUB
files or firmware entry until the new boot path has been tested successfully.

### Enable Secure Boot after boot testing

Secure Boot is deliberately a second stage. Once both operating systems boot
successfully through Limine and a recovery route is available:

1. Create the local Secure Boot keys as root:

   ```sh
   sudo sbctl create-keys
   ```

2. Enter UEFI Setup Mode using the motherboard firmware's Secure Boot controls.
   Do not enable Secure Boot enforcement yet.
3. Enroll the custom keys while retaining Microsoft and firmware vendor keys:

   ```sh
   sudo sbctl enroll-keys --microsoft --firmware-builtin
   ```

4. Change `boot.loader.limine.secureBoot.enable` to `true` in
   `modules/nixos/boot.nix`, rebuild, and check:

   ```sh
   sudo sbctl status
   sudo sbctl verify
   ```

5. Enable Secure Boot in UEFI firmware and verify that both Limine/NixOS and
   Windows Boot Manager still start.

Do not use automatic key enrollment for this host. Keep the existing NixOS
LUKS recovery passphrase available and retain the old GRUB firmware entry
until the Secure Boot configuration has been tested. Secure Boot support is
firmware-dependent; a successful build alone does not prove that the machine
will boot with enforcement enabled.

Starforge does not configure Windows volume encryption. Windows encryption
can be enabled separately after the new boot chain and Secure Boot have been
validated. The existing NixOS LUKS/Btrfs arrangement is unchanged.

## Virtualisation

The host uses AMD KVM with QEMU and libvirt:

- `kvm-amd` is retained in the generated hardware configuration.
- `virtualisation.libvirtd` provides the system VM daemon.
- QEMU guests run as the dedicated unprivileged `qemu-libvirtd` account.
- `swtpm` is enabled for virtual TPM 2.0 devices, useful for Windows 11 guests.
- OVMF/UEFI firmware is supplied by the QEMU/libvirt module.
- Virt-manager provides the graphical manager.
- SPICE USB redirection is enabled.
- The desktop user belongs to the `libvirtd` group.

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

- The NixOS firewall is explicitly enabled, with no extra inbound ports opened.
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
- Sudo requires a password and its authentication timestamp is limited to
  five minutes.
- Nix builds remain sandboxed; only root and wheel members may use the daemon,
  while only root is a trusted Nix user.
- Existing LUKS full-disk encryption and encrypted Btrfs layout are preserved.
- Limine's built-in Secure Boot support is available, but enforcement remains
  disabled until keys are manually created and enrolled and the boot path is tested.

This is a practical workstation baseline, not a claim of complete isolation.
The AppArmor LSM is enabled, with the initial curl policy deliberately in
complain mode; it is not yet a general application sandbox. TPM-backed disk unlock and device-specific USB restrictions still need
separate validation. IOMMU is enabled as a base facility, but actual PCI
passthrough remains unconfigured until a suitable device and IOMMU group are
reviewed. Kernel-module locking is
intentionally omitted because this machine must load hardware, networking,
Bluetooth, and KVM modules.

### AppArmor rollout

AppArmor is enabled through the NixOS module. It adds the AppArmor kernel
parameter, registers the LSM, installs the policy loader service, and provides
the AppArmor management utilities. A reboot is required before the kernel LSM
becomes active.

One host-specific policy is currently loaded for the Nixpkgs `curl` binary.
It starts in **complain** mode: operations that the policy does not explicitly
allow are logged but not blocked. This gives us real workload data before
enforcement. It does not mean that Firefox, the desktop, every system service,
or arbitrary user processes are already confined.

After deploying this module and rebooting, verify the LSM and policy loader:

```sh
cat /sys/kernel/security/lsm
sudo aa-status
sudo systemctl status apparmor.service
readlink -f "$(command -v curl)"
```

Inspect complain-mode events from the current boot:

```sh
sudo journalctl -k -b | grep 'apparmor='
```

To review logged access patterns interactively, use:

```sh
sudo journalctl -b --since today --grep='apparmor=' | sudo aa-logprof
```

Do not switch the curl policy to `enforce` merely because the profile loads.
First exercise the real commands and download destinations you use, review the
logs, update the policy, and test the enforced version. Keep
`killUnconfinedConfinables` disabled so profile changes do not automatically
send SIGTERM to running desktop processes.

NixOS provides the AppArmor LSM and policy-loading module, but its AppArmor
integration is not yet as complete as on distributions with mature,
distribution-maintained application policy sets. Treat each additional profile
as a separate, workload-tested change rather than assuming that installing
the upstream profile package automatically confines applications.

### USBGuard device management

USBGuard starts after the initial udev device enumeration has settled. Its
bootstrap policy is intentionally conservative without guessing the IDs of
your keyboard, mouse, hubs, Bluetooth adapter, or other host-specific devices:

- Devices already connected when USBGuard starts keep their existing
  authorization state.
- Devices inserted after the daemon starts are blocked unless an explicit
  rule allows them.
- Unknown devices default to block.
- Only root can use the USBGuard IPC interface.

Inspect the initial state and blocked devices:

```sh
sudo usbguard list-devices --tree
sudo usbguard list-devices --blocked
sudo journalctl -u usbguard -b
```

To approve a trusted newly inserted device and persist that decision:

```sh
sudo usbguard allow-device --permanent <device-id>
```

The device ID is the first numeric field in `usbguard list-devices`, not the
USB vendor:product ID. Persistent rules are stored locally in
`/var/lib/usbguard/rules.conf` and are deliberately not committed to Git,
because they contain hardware-specific identifiers.

After reviewing the actual device inventory, a complete initial policy can
also be generated with `sudo usbguard generate-policy`. Review the generated
rules before installing them. Only after a complete allowlist exists should
`presentDevicePolicy` be changed from `keep` to `apply-policy`; otherwise
devices already connected at boot could be blocked. Keep a working input
device available while testing policy changes.

## Desktop

- Niri is enabled at the NixOS level so greetd can launch the session.
- Home Manager owns and validates the generated Niri KDL configuration.
- Noctalia is configured through its Home Manager module and validates its TOML.
- Noctalia uses the Catppuccin built-in palette and JetBrainsMono Nerd Font.
- Kitty and Zsh configuration remain owned by terminal-dotfiles to avoid
  competing Home Manager definitions.

Noctalia is pinned to its `cachix` branch. Its Nixpkgs input deliberately does
not follow the root Nixpkgs input: this preserves derivation compatibility
with the Noctalia Cachix binary cache. The nested Nixpkgs revision is pinned
in `flake.lock`.

## CI and build caching

GitHub Actions runs two independent jobs in parallel:

1. **Validate Nix configuration** formats tracked Nix files, runs
   `statix` and `deadnix` using the flake's pinned development shell, and
   evaluates flake outputs with `nix flake check --no-build`. This is the
   quick feedback path; it does not compile the complete operating system.
2. **Build Starforge system** builds the full
   `nixosConfigurations.starforge.config.system.build.toplevel` closure.
   This remains the expensive integration check.

Both jobs use the committed `flake.lock`; CI does not update dependencies.
The full build can use a public Cachix binary cache to reuse store paths
between runs. Pull requests receive read-only cache access. Only pushes to
`main` receive the cache write token and can publish build results.

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

GitHub Actions dependencies are checked weekly by Dependabot. Updates arrive
as pull requests and are not merged automatically.

This workflow performs CI only. It never activates a NixOS generation or
deploys to the workstation.

## Static analysis

The flake provides a development shell with `statix` and `deadnix` from the
locked Nixpkgs revision. The checks cover maintained Nix files and deliberately
exclude the NixOS-generated `hosts/starforge/hardware-configuration.nix`.
Run them locally before opening a PR:

```sh
nix develop
mapfile -t nix_files < <(git ls-files "*.nix" ":!:hosts/starforge/hardware-configuration.nix")
statix check "${nix_files[@]}"
deadnix --fail "${nix_files[@]}"
```

## Validate and build locally

Run these commands from the repository root:

```sh
nix fmt
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
- Keep the previous GRUB UEFI boot entry until Limine and Secure Boot have
  both passed real reboot tests.

### Restic backup and recovery

The configuration defines a manual Restic backup profile for `/home/katossh`
and `/etc/nixos`. It excludes disposable caches and the desktop trash. The Nix store is not backed up because it is
reproducible from the flake and its lock file. Libvirt VM disk images are not
included; shut down a guest and back up its image separately when that data
needs protection.

The profile deliberately has **no systemd timer** until a real backup
destination is selected and tested. The service is manual-only, so backups
cannot run on a timer before a storage target is chosen. The repository
location and encryption password are read from root-only files outside the
Nix store:

- `/etc/starforge/restic-repository`: one-line Restic repository location
  (for example, a mounted external disk path or a remote repository URL).
- `/etc/starforge/restic-password`: repository password; losing it makes the
  encrypted backup unrecoverable.

Create root-only files without putting the password or repository location
in Git or the Nix store. Generate the password with a password manager, keep
an independent recovery copy outside this workstation, and then enter it into
the file:

```sh
sudo install -d -m 0700 /etc/starforge
sudo install -m 0600 /dev/null /etc/starforge/restic-password
sudoedit /etc/starforge/restic-password
sudo install -m 0600 /dev/null /etc/starforge/restic-repository
sudoedit /etc/starforge/restic-repository
```

The repository file contains one line: the selected local path or remote
repository URL. For a removable disk, mount it and verify the actual mount
with `findmnt` before initializing or running a backup. The current service
does not hard-code a mountpoint because the destination has not been selected.

Initialize the repository once, then run the manual backup service:

```sh
sudo env RESTIC_REPOSITORY_FILE=/etc/starforge/restic-repository \
  RESTIC_PASSWORD_FILE=/etc/starforge/restic-password restic init
sudo systemctl start restic-backups-starforge.service
sudo systemctl status restic-backups-starforge.service
```

The retention policy keeps 7 daily, 4 weekly, 12 monthly, and 2 yearly
snapshots. The service prunes according to that policy when it is manually
run. Verify repository integrity periodically and perform an actual test
restore; a successful backup job alone does not prove recoverability:

```sh
sudo env RESTIC_REPOSITORY_FILE=/etc/starforge/restic-repository \
  RESTIC_PASSWORD_FILE=/etc/starforge/restic-password restic snapshots
sudo env RESTIC_REPOSITORY_FILE=/etc/starforge/restic-repository \
  RESTIC_PASSWORD_FILE=/etc/starforge/restic-password restic check
sudo env RESTIC_REPOSITORY_FILE=/etc/starforge/restic-repository \
  RESTIC_PASSWORD_FILE=/etc/starforge/restic-password restic restore latest \
  --target /tmp/starforge-restore-test
```

Inspect the restored files before deleting the temporary restore directory.
Keep at least one backup copy disconnected from the workstation when it is not
being updated. A single local copy on another partition is not a disaster
recovery strategy.

The profile is intentionally manual until the backup disk or remote endpoint,
mount dependency, secret provisioning, and restore procedure are verified.
Only then should a persistent timer be enabled. The password file is a
temporary host-local secret mechanism; a later sops-nix/agenix rollout can
manage it declaratively without committing the plaintext password.

The old pre-dotfiles configuration is retained as a historical snapshot in
`archive/configuration.nix.before-dotfiles`; it is not imported by the flake.
