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

The default libvirt NAT network may need to be enabled once:

```sh
sudo virsh net-autostart default
sudo virsh net-start default
```

Useful checks:

```sh
ls -l /dev/kvm
virsh -c qemu:///system list --all
```

Because QEMU runs unprivileged, direct USB/PCI device assignment may require
additional per-device permissions. Do not solve that by running all QEMU
processes as root; add narrowly scoped access for the specific device instead.

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
complain mode; it is not yet a general application sandbox. TPM-backed disk
unlock, container isolation, and device-specific USB restrictions need
separate validation before enabling them. Kernel-module locking is
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

1. **Validate Nix configuration** formats tracked Nix files and evaluates
   flake outputs with `nix flake check --no-build`. This is the quick feedback
   path; it does not compile the complete operating system.
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
never receive the write token. The cache must be public for token-free reads
from pull requests.

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

The jobs are separate checks. To make them mandatory before merging, configure
branch protection or a repository ruleset for `main` and require both
`Validate Nix configuration` and `Build Starforge system`.

This workflow performs CI only. It never activates a NixOS generation or
deploys to the workstation.

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

The old pre-dotfiles configuration is retained as a historical snapshot in
`archive/configuration.nix.before-dotfiles`; it is not imported by the flake.
