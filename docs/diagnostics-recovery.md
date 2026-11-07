# Diagnostics and recovery

Starforge provides separate commands for routine health checks, security
auditing, recovery guidance, and configuration validation. They have
different purposes and side-effect profiles.

## Commands

| Command | Purpose | Changes system state? |
|---|---|---|
| `nixcfg status` | Hardware and resource snapshot, including failed systemd units. | No |
| `nixcfg doctor` | Checks required system services, the active desktop session, systemd failures, root filesystem capacity, and the active system profile. | No |
| `nixcfg boot` | Shows boot timing, the 15 slowest systemd units, and the critical dependency chain. | No |
| `nixcfg recovery` | Lists available system generations and prints host-specific recovery instructions. | No |
| `nixcfg audit` | Performs the existing P0 security checks for Secure Boot, AppArmor, USBGuard, kernel mitigations, and AMD IOMMU. | No; it may request sudo for read-only checks and may show the documented fwupd upload prompt. |
| `nixcfg check` | Runs formatting, static analysis, flake evaluation, and the full system build. | Does not activate a generation; it may download/build Nix store paths. |

Run `nixcfg doctor` for a concise health report. It does not prompt for sudo,
restart units, repair services, alter configuration, or change boot entries.
Desktop checks are skipped when no Wayland session is active.

## Boot analysis

Run:

```sh
nixcfg boot
```

The command uses `systemd-analyze` to display firmware/loader, kernel, initrd,
and userspace timing when the firmware exposes those measurements. It then
lists the 15 units with the longest recorded activation times and prints the
systemd critical dependency chain for the current boot.

This is a read-only inspection. It does not restart, stop, disable, or
reconfigure any unit. Use the output to identify candidates for investigation,
not as an instruction to disable services.

Interpret the results carefully:

- `systemd-analyze blame` durations are not additive because units start in
  parallel; a long duration does not necessarily delay reaching the graphical
  session.
- `systemd-analyze critical-chain` shows a dependency path that affected the
  target's timing, not every possible source of boot delay.
- Firmware and boot-loader timing may be unavailable on systems that do not
  expose the relevant EFI measurements.
- Compare results across boots before treating a one-off delay as a regression.

## Doctor result states

- **OK** — the expected state was verified.
- **WARN** — a degraded or transitional state needs review, but does not prove
  that a required component is unavailable.
- **ERROR** — a required component is missing, masked, inactive, or failed.
- **SKIP** — the check does not apply to the current context (for example, no
  active Wayland session).
- **UNKNOWN** — the check could not establish the state, such as when the
  systemd manager is inaccessible.

The command uses stable exit codes:

- `0`: no required check returned `ERROR`; warnings may still be present.
- `1`: at least one required check returned `ERROR`.
- `2`: no errors were found, but one or more checks returned `UNKNOWN`.

Warnings and skipped checks do not alter the exit code. Always read the full
report; exit code 0 does not mean that every optional or contextual check ran.

For each failed service, the report names the unit and suggests a read-only
inspection command. Use the relevant evidence before deciding whether a
service should be restarted or reconfigured.

## Recovery

The recovery command is an information-only aid:

```sh
nixcfg recovery
```

It lists the current system profile and the generations recorded for it.
It does not execute any repair or rollback command.

### The system boots, but the current generation is broken

From a terminal or TTY in the running NixOS system:

```sh
sudo nixos-rebuild switch --rollback
nixcfg doctor
```

This switches to the previous system generation. It does not restore arbitrary
home-directory data or reverse external changes.

### The current generation will not boot

Use the Limine boot menu and select an earlier NixOS generation. The current
host configuration retains up to five generations in the Limine menu. The
separate Windows Boot Manager entry is not a NixOS recovery entry.

After booting a working generation, inspect the state with:

```sh
nixcfg doctor
nixcfg recovery
```

Do not delete generations or run garbage collection before confirming that a
known-good generation is available.

### A build failed before activation

A failed evaluation or build has not activated a new generation. Inspect the
error and the source diff, correct the declarative configuration, then rerun
the validation. Do not use rollback as a substitute for fixing a build error.

### Recovering individual files from Snapper snapshots

Inspect the snapshots:

```sh
sudo snapper -c root list
sudo snapper -c home list
```

Root snapshots are under `/.snapshots/<number>/snapshot/`; home snapshots are
under `/home/.snapshots/<number>/snapshot/`. Restore individual files only
after checking the source and destination.

These snapshots share the same physical NVMe device and are not independent
backups. The `/nix` and `/var/log` subvolumes are not included in the root
snapshot. Do not treat a root snapshot as a complete system-generation
rollback or as a replacement for an external backup.

### The machine cannot boot an installed generation

Boot a NixOS installer ISO in UEFI mode and use the existing LUKS passphrase.
The fresh-install section in `INSTALL.md` documents the current disk layout
and mount points, but its `install.sh --install` path reinstalls the system;
it is not a tested chroot-repair procedure.

Do not format partitions, recreate Btrfs subvolumes, regenerate the committed
hardware configuration, alter LUKS keys, or enroll new Secure Boot keys as
generic troubleshooting steps. Those actions need a separate, host-specific
recovery plan.

The MSI firmware's reported Secure Boot FQ0001 quirk remains a documented
platform caveat. Preserve known-good boot entries and key material. Use
`nixcfg audit` for the deeper read-only security review before making any
security or boot-chain changes.

## What these checks do not do

- They do not guarantee that every application or hardware device works.
- They do not repair failed services.
- They do not automatically roll back NixOS.
- They do not restore user data or provide off-device backup.
- They do not modify Secure Boot, LUKS, partitions, filesystem layout, or
  bootloader configuration.
