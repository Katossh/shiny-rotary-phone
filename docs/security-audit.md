# P0 security audit

The configuration provides a read-only diagnostic command:

```sh
nixcfg audit
```

It checks Secure Boot state and EFI signatures, fwupd/ESP discovery, AppArmor
status and audit events, USBGuard device inventory and rules, kernel Lockdown
and taint metadata, CPU vulnerability mitigations, AMD P-State, selected sysctl
values, AMD IOMMU initialization, and PCI device bindings.

The command does not modify firmware variables, Secure Boot keys, USBGuard rules,
AppArmor profiles, kernel parameters, or system configuration. It requests sudo
once for root-only checks. Without elevated privileges, those checks are marked
as skipped rather than silently omitted.

The fwupd security check runs last. Before invoking it, the audit checks the
local fwupd remote configuration for `AutomaticSecurityReports=true`; when
found, it skips the check because fwupd can upload HSI results without asking.
Otherwise, fwupd may display an upload prompt whose default answer is **N**.
Press Enter or N to decline. Its follow-up question about asking again later
does not upload the current report.

## 1. Secure Boot and MSI FQ0001

Review these outputs together:

- `sbctl status`: enrolled/setup state and firmware quirk detection.
- `sbctl verify`: EFI files on the ESP and files registered in the sbctl
  signing database. This check is scoped to the local sbctl signing database
  key; it is not a complete validation against every certificate enrolled in
  UEFI. In particular, Windows Boot Manager may be Microsoft-signed rather
  than signed by the local db key enrolled on this host. Treat such output as a review item,
  not an instruction to sign or replace the Windows loader.
- `bootctl status`: UEFI and Secure Boot state reported by systemd-boot's
  firmware interface. This is independent of whether Limine is the active loader.
- `fwupdmgr security`: firmware security attributes, when supported. Run the
  fwupd client as the normal user; it uses its privileged daemon and PolicyKit.
- `fwupdmgr get-devices`: device inventory.

- `fwupdtool esp-list --verbose`: detailed ESP discovery diagnostics.
- `findmnt` and `lsblk`: the actual `/boot` mount, filesystem, and GPT
  partition type. For GPT, the EFI System Partition type GUID is
  `c12a7328-f81f-11d2-ba4b-00a0c93ec93b`; a FAT filesystem alone does not prove
  that the partition is typed as an ESP.
- `systemctl status udisks2.service`: runtime block-device discovery state.
  The NixOS fwupd module enables UDisks 2, but its runtime availability still
  needs to be checked.
- `fwupdmgr get-bios-settings`: optional read-only inspection of firmware
  attributes, when the motherboard exposes them. Do not write firmware settings
  as part of this audit.

MSI AMD 600-series motherboards are listed in the sbctl FQ0001 advisory. The
The current workstation uses an MSI B650M board, so this advisory applies to the platform.
The advisory describes firmware that may execute EFI images despite a Secure Boot
policy violation. Its documented firmware-side mitigation is to use Custom
Secure Boot mode and either set Option ROM, Removable Media, and Fixed Media
execution policies to **Deny Execute**, or select the **Maximum Security**
preset when the firmware exposes that control.

The workstation profile currently documents Maximum Security as selected, but the FQ0001
warning must remain an explicit review item until the exact firmware settings
and current sbctl detection output are checked on the host. A green Secure Boot
status alone is not evidence that the firmware rejects every untrusted EFI
image.

Do not run key enrollment, key reset, key rotation, or `sbctl sign-all` as part
of an audit. Do not delete or replace `dbx`. Preserve the existing Microsoft
certificates and Windows Boot Manager chainloading path. Any experiment with
an unsigned EFI image must use a removable test medium and a recovery path;
do not alter the working NixOS or Windows boot files to test enforcement.

## 2. AppArmor

The current baseline enforces the curl profile. Firefox, Chromium, LocalSend,
Telegram, Discord, mpv, yt-dlp, VS Code, and Zed are intentionally configured
in complain mode.

Review `aa-status` and the kernel journal entries. In complain mode, operations
that would have been denied are generally logged as `apparmor="ALLOWED"`
with a `denied_mask`; explicit deny rules remain effective.

Before changing a profile to `enforce`:

1. Use the application normally, including updates, downloads, media playback,
   portals, screen sharing, GPU acceleration, extensions, language servers,
   terminals, and child processes where applicable.
2. Review the resulting AppArmor events and identify the executable, path,
   operation, and profile involved.
3. Add only the narrowest required rule.
4. Test the profile in a temporary generation before making it the default.

Do not promote browser or editor profiles wholesale. Editors execute user code
and spawn tools; browsers have complex helper and portal workflows. Their
profiles need separate review.

## 3. USBGuard

USBGuard is currently configured with a permissive default-allow policy.
This preserves device usability but is not an allowlist.

Review `usbguard list-devices`, `usbguard list-rules`, and the service journal.
Identify every device needed for normal operation, including internal USB
devices, Bluetooth/Wi-Fi components exposed over USB, keyboard, mouse, audio
receivers, storage devices, and recovery peripherals.

Do not switch `implicitPolicyTarget` to `block` until the inventory has been
reviewed and explicit rules have been prepared and tested. A careless default
block can disable input devices or other essential peripherals. The intended
target is a small, explicit allowlist with a documented recovery procedure,
not an unreviewed generated policy.

## 4. Kernel hardening and AMD IOMMU

The current configuration already sets:

- `slab_nomerge`
- `page_alloc.shuffle=1`
- `randomize_kstack_offset=on`

It also configures kernel pointer/dmesg restrictions, Yama ptrace scope,
unprivileged BPF restrictions, and filesystem protections in
`modules/nixos/security.nix`. AMD P-State is imported through the
`nixos-hardware` Raphael/P-State modules.

The audit reads the running kernel's vulnerability status, active cpufreq
driver/EPP, kernel command line, Lockdown state from
`/sys/kernel/security/lockdown`, and the raw kernel taint value with its set
flags decoded from `/proc/sys/kernel/tainted`. It also reads relevant sysctls,
AMD-Vi/IOMMU kernel logs, IOMMU groups, and PCI device bindings.

A nonzero kernel taint value is diagnostic metadata, not proof of compromise.
Preserve the raw value and every decoded flag; identify the corresponding
module, warning, firmware workaround, or event before deciding on remediation.

The `lockdown=integrity` kernel parameter can disable kernel interfaces that
would let userspace modify the running kernel. It is not enabled automatically
by this audit change: inspect the active module set and test it in a separate
NixOS generation with a known-good rollback path before making it permanent.
The kernel documents `integrity` and the stricter `confidentiality` mode in its
[command-line parameter reference](https://docs.kernel.org/admin-guide/kernel-parameters.html).

Do not add `amd_iommu=on`, `amd_iommu=force_enable`, `iommu=pt`, or VFIO
bindings speculatively. AMD IOMMU should be detected from firmware tables; PCI
passthrough is not part of this P0 baseline. Likewise, evaluate
`init_on_alloc=1` and `init_on_free=1` with the actual kernel configuration
and workload before enabling them, because they can add memory-allocation
overhead.

## Audit hand-off

Run `nixcfg audit` from the installed system and review the output
for machine-identifying details before sharing it.
The next changes should be based on these observations:

- Secure Boot: reconcile FQ0001, firmware settings, and EFI signature results.
- AppArmor: identify real complain-mode events before enforcing individual
  desktop profiles.
- USBGuard: create and test explicit rules from the actual device inventory.
- Kernel: inspect decoded taint flags and Lockdown state; identify the cause of
  every taint flag before remediation.
- fwupd: verify ESP partition type, `/boot` mount options, and UDisks discovery
  before changing partition metadata or fwupd settings.

This audit is intentionally a collection step; it does not claim that any
unverified security control is effective.
