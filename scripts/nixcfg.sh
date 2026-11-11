#!/usr/bin/env bash

usage() {
  cat <<'EOF'
Usage:
  nixcfg status          Show a concise workstation hardware/status snapshot.
  nixcfg doctor          Run read-only system and desktop health checks.
  nixcfg boot            Show boot timing, slow units, and the critical chain.
  nixcfg recovery        List system generations and show recovery guidance.
  nixcfg audit           Collect read-only P0 security diagnostics.
  nixcfg check           Run local formatting, lint, evaluation, and build checks.

Doctor exit codes:
  0  No required checks reported an error (warnings may still be present).
  1  One or more required checks reported an error.
  2  At least one check was unknown or could not be completed, with no errors.
EOF
}

show_status() {
  local cpu_model load_average failed_units system_generation

  printf '\nNixOS system status\n'
  printf '%s\n' '======================='
  printf 'Kernel: %s\n' "$(uname -r)"

  cpu_model="$(awk -F: '/model name/ { sub(/^[[:space:]]+/, "", $2); print $2; exit }' /proc/cpuinfo)"
  printf 'CPU: %s\n' "${cpu_model:-unknown}"

  load_average="$(awk '{ print $1 " " $2 " " $3 }' /proc/loadavg)"
  printf 'Load average (1/5/15m): %s\n' "$load_average"

  printf '\nMemory\n'
  free -h | awk 'NR == 1 || /^Mem:/ { print }'

  printf '\nRoot filesystem\n'
  df -h / | awk 'NR == 1 || NR == 2 { print }'

  printf '\nAMD GPU\n'
  if ! amdgpu_top --list 2>/dev/null; then
    printf 'GPU telemetry unavailable.\n'
  fi

  printf '\nHardware sensors\n'
  if ! sensors 2>/dev/null; then
    printf 'No readable sensor data.\n'
  fi

  printf '\nFailed systemd units\n'
  failed_units="$(systemctl --failed --no-legend --plain 2>/dev/null || true)"
  if [[ -n "$failed_units" ]]; then
    printf '%s\n' "$failed_units"
  else
    printf 'None\n'
  fi

  system_generation="$(readlink /nix/var/nix/profiles/system 2>/dev/null || true)"
  printf '\nSystem generation: %s\n\n' "${system_generation:-unavailable}"
}

SUDO_AVAILABLE=false

run_diagnostic() {
  local privilege="$1"
  shift
  local executable="$1"
  local status

  if ! command -v "$executable" >/dev/null 2>&1; then
    printf '[unavailable] %s is not installed.\n' "$executable"
    return 0
  fi

  printf '\n$'
  printf ' %q' "$@"
  printf '\n'

  if [[ "$privilege" == "root" ]] && (( EUID != 0 )); then
    if [[ "$SUDO_AVAILABLE" != "true" ]]; then
      printf '[skipped] Root privileges are unavailable.\n'
      return 0
    fi
    if sudo "$@"; then
      return 0
    else
      status=$?
    fi
  else
    if "$@"; then
      return 0
    else
      status=$?
    fi
  fi

  printf '[command exited with status %s; audit continued]\n' "$status"
  return 0
}

show_kernel_taint() {
  local raw_taint taint_number bit
  local -a reasons=(
    "proprietary module loaded"
    "module force-loaded"
    "out-of-spec hardware or configuration"
    "module force-unloaded"
    "machine check exception"
    "bad page state"
    "userspace requested taint"
    "kernel OOPS or BUG"
    "ACPI table overridden"
    "kernel warning"
    "staging driver loaded"
    "firmware workaround applied"
    "out-of-tree module loaded"
    "unsigned module loaded"
    "soft lockup occurred"
    "kernel livepatch applied"
    "auxiliary distribution taint"
    "randstruct plugin enabled"
    "in-kernel test executed"
    "fwctl mutating debug operation used"
  )

  if [[ ! -r /proc/sys/kernel/tainted ]]; then
    printf 'Kernel taint interface is unavailable.\n'
    return
  fi

  raw_taint="$(< /proc/sys/kernel/tainted)"
  printf 'Raw kernel taint value: %s\n' "$raw_taint"

  if [[ ! "$raw_taint" =~ ^[0-9]+$ ]]; then
    printf 'Kernel taint value is not a decimal integer; decoding skipped.\n'
    return
  fi

  taint_number=$((10#$raw_taint))
  if (( taint_number == 0 )); then
    printf 'No kernel taint flags are set.\n'
    return
  fi

  printf 'Decoded taint flags:\n'
  for bit in "${!reasons[@]}"; do
    if (( (taint_number & (1 << bit)) != 0 )); then
      printf '  bit %s: %s\n' "$bit" "${reasons[$bit]}"
    fi
  done
}

security_audit() {
  local path group device remote_dir automatic_security_reports=false
  SUDO_AVAILABLE=false

  if (( EUID != 0 )); then
    if command -v sudo >/dev/null 2>&1 && sudo -v; then
      SUDO_AVAILABLE=true
    else
      printf 'Root-only checks will be skipped. Re-run with sudo for a complete audit.\n'
    fi
  fi

  printf '\nNixOS P0 security audit (read-only)\n'
  printf '%s\n' '======================================'
  printf 'Host: %s\n' "$(hostname)"
  printf 'Date: %s\n' "$(date --iso-8601=seconds)"
  printf 'Kernel: %s\n' "$(uname -r)"
  printf '\nThis command does not change firmware, keys, policies, or system configuration.\n'

  printf '\n== 1. Secure Boot and EFI ==\n'
  run_diagnostic user sbctl status
  run_diagnostic root sbctl verify
  run_diagnostic user bootctl status --no-pager
  run_diagnostic user fwupdmgr get-devices
  run_diagnostic user fwupdmgr get-bios-settings
  run_diagnostic root fwupdtool esp-list --verbose
  run_diagnostic user findmnt --noheadings --output SOURCE,FSTYPE,OPTIONS --target /boot
  run_diagnostic user lsblk --paths --output NAME,PARTTYPE,PARTTYPENAME,FSTYPE,MOUNTPOINTS
  run_diagnostic user systemctl status udisks2.service --no-pager

  printf '\n== 2. AppArmor ==\n'
  run_diagnostic user systemctl is-active apparmor.service
  run_diagnostic root aa-status
  run_diagnostic root journalctl -k -b --no-pager --grep=apparmor= -n 100

  printf '\n== 3. USBGuard ==\n'
  run_diagnostic user systemctl is-active usbguard.service
  run_diagnostic root usbguard list-devices
  run_diagnostic root usbguard list-rules
  run_diagnostic root journalctl -u usbguard.service -b --no-pager -n 80

  printf '\n== 4. Kernel command line and mitigations ==\n'
  printf '$ cat /proc/cmdline\n'
  cat /proc/cmdline

  printf '\nKernel Lockdown state:\n'
  if [[ -r /sys/kernel/security/lockdown ]]; then
    cat /sys/kernel/security/lockdown
  else
    printf 'Unavailable (securityfs or the kernel Lockdown interface is not exposed).\n'
  fi
  run_diagnostic root journalctl -k -b --no-pager --grep='lockdown|Lockdown' -n 50

  printf '\nKernel taint state:\n'
  show_kernel_taint

  printf '\nCPU vulnerability status:\n'
  if [[ -d /sys/devices/system/cpu/vulnerabilities ]]; then
    for path in /sys/devices/system/cpu/vulnerabilities/*; do
      [[ -r "$path" ]] || continue
      printf '%s: ' "${path##*/}"
      cat "$path"
    done
  else
    printf 'CPU vulnerability sysfs interface unavailable.\n'
  fi

  printf '\nCPU frequency driver and EPP:\n'
  local found_policy=false
  for path in /sys/devices/system/cpu/cpufreq/policy*; do
    [[ -d "$path" ]] || continue
    found_policy=true
    printf '%s: ' "${path##*/}"
    if [[ -r "$path/scaling_driver" ]]; then
      printf 'driver='
      cat "$path/scaling_driver"
    else
      printf 'driver=unavailable\n'
    fi
    if [[ -r "$path/energy_performance_preference" ]]; then
      printf '  EPP='
      cat "$path/energy_performance_preference"
    fi
  done
  if [[ "$found_policy" == "false" ]]; then
    printf 'No cpufreq policy directories found.\n'
  fi

  printf '\nRelevant sysctl values:\n'
  run_diagnostic user sysctl \
    kernel.dmesg_restrict \
    kernel.kptr_restrict \
    kernel.yama.ptrace_scope \
    kernel.unprivileged_bpf_disabled \
    net.core.bpf_jit_harden \
    fs.protected_hardlinks \
    fs.protected_symlinks \
    fs.protected_fifos \
    fs.protected_regular

  printf '\n== 5. AMD IOMMU ==\n'
  run_diagnostic root journalctl -k -b --no-pager --grep='AMD-Vi|IOMMU|IVRS' -n 100
  if [[ -d /sys/kernel/iommu_groups ]]; then
    printf 'IOMMU groups: '
    find /sys/kernel/iommu_groups -mindepth 1 -maxdepth 1 -type d | wc -l
    for group in /sys/kernel/iommu_groups/*; do
      [[ -d "$group/devices" ]] || continue
      printf 'Group %s:' "${group##*/}"
      for device in "$group"/devices/*; do
        [[ -e "$device" ]] || continue
        printf ' %s' "${device##*/}"
      done
      printf '\n'
    done
  else
    printf 'IOMMU group sysfs interface is unavailable.\n'
  fi
  run_diagnostic user lspci -nnk

  printf '\n== 6. Firmware security (fwupd) ==\n'
  if (( EUID != 0 )) && [[ "$SUDO_AVAILABLE" != "true" ]]; then
    printf '[skipped] Cannot verify fwupd remote reporting settings without root access. Re-run the audit with sudo to avoid an unverified upload setting.\n'
  else
    for remote_dir in /etc/fwupd/remotes.d /var/lib/fwupd/remotes.d; do
      [[ -d "$remote_dir" ]] || continue
      if (( EUID == 0 )); then
        if grep -RiqE '^[[:space:]]*AutomaticSecurityReports[[:space:]]*=[[:space:]]*true' "$remote_dir" 2>/dev/null; then
          automatic_security_reports=true
          break
        fi
      elif sudo grep -RiqE '^[[:space:]]*AutomaticSecurityReports[[:space:]]*=[[:space:]]*true' "$remote_dir" 2>/dev/null; then
        automatic_security_reports=true
        break
      fi
    done

    if [[ "$automatic_security_reports" == "true" ]]; then
      printf '[skipped] fwupd automatic security reports are enabled. The security command could upload HSI data without asking.\n'
    else
      printf 'fwupdmgr may ask to upload anonymous HSI results to LVFS. Its upload prompt defaults to N; press Enter or N to decline.\n'
      printf 'The follow-up question controls whether fwupd asks again in the future.\n'
      run_diagnostic user fwupdmgr security
    fi
  fi

  printf '\n== End of read-only security audit ==\n'
  printf 'Review the output before changing Secure Boot, AppArmor, USBGuard, or kernel settings.\n\n'
}


DOCTOR_ERROR_COUNT=0
DOCTOR_WARNING_COUNT=0
DOCTOR_UNKNOWN_COUNT=0
DOCTOR_SKIPPED_COUNT=0

doctor_report() {
  local severity="$1"
  local label="$2"
  local observed="$3"
  local next_step="${4:-}"

  printf '[%s] %s: %s\n' "$severity" "$label" "$observed"
  if [[ -n "$next_step" ]]; then
    printf '       Next: %s\n' "$next_step"
  fi

  case "$severity" in
    ERROR) DOCTOR_ERROR_COUNT=$((DOCTOR_ERROR_COUNT + 1)) ;;
    WARN) DOCTOR_WARNING_COUNT=$((DOCTOR_WARNING_COUNT + 1)) ;;
    UNKNOWN) DOCTOR_UNKNOWN_COUNT=$((DOCTOR_UNKNOWN_COUNT + 1)) ;;
    SKIP) DOCTOR_SKIPPED_COUNT=$((DOCTOR_SKIPPED_COUNT + 1)) ;;
  esac
}

doctor_check_system_unit() {
  local unit="$1"
  local label="$2"
  local load_state state

  load_state="$(systemctl show --property=LoadState --value "$unit" 2>/dev/null || true)"
  state="$(systemctl is-active "$unit" 2>/dev/null || true)"

  case "$load_state" in
    not-found)
      doctor_report ERROR "$label" "unit $unit was not found although the workstation profile expects it" \
        "Check the active system generation and the module that declares $unit."
      return
      ;;
    masked)
      doctor_report ERROR "$label" "unit $unit is masked" \
        "Inspect with: systemctl status $unit --no-pager"
      return
      ;;
    loaded) ;;
    *)
      doctor_report UNKNOWN "$label" "systemd could not determine the load state of $unit" \
        "Inspect with: systemctl status $unit --no-pager"
      return
      ;;
  esac

  case "$state" in
    active)
      doctor_report OK "$label" "$unit is active"
      ;;
    inactive|failed|dead)
      doctor_report ERROR "$label" "$unit is $state" \
        "Inspect with: systemctl status $unit --no-pager; journalctl -u $unit -b --no-pager -n 80"
      ;;
    activating|deactivating|reloading)
      doctor_report WARN "$label" "$unit is $state" \
        "Re-check with: systemctl status $unit --no-pager"
      ;;
    *)
      doctor_report UNKNOWN "$label" "systemd returned state '${state:-no response}' for $unit" \
        "Inspect with: systemctl status $unit --no-pager"
      ;;
  esac
}

doctor_check_user_unit() {
  local unit="$1"
  local label="$2"
  local load_state state

  load_state="$(systemctl --user show --property=LoadState --value "$unit" 2>/dev/null || true)"
  state="$(systemctl --user is-active "$unit" 2>/dev/null || true)"

  case "$load_state" in
    not-found)
      doctor_report ERROR "$label" "user unit $unit was not found in the active session" \
        "Check the active Home Manager generation and the module that declares $unit."
      return
      ;;
    masked)
      doctor_report ERROR "$label" "user unit $unit is masked" \
        "Inspect with: systemctl --user status $unit --no-pager"
      return
      ;;
    loaded) ;;
    *)
      doctor_report UNKNOWN "$label" "the user systemd manager could not determine the load state of $unit" \
        "Inspect with: systemctl --user status $unit --no-pager"
      return
      ;;
  esac

  case "$state" in
    active)
      doctor_report OK "$label" "$unit is active"
      ;;
    inactive|failed|dead)
      doctor_report ERROR "$label" "$unit is $state" \
        "Inspect with: systemctl --user status $unit --no-pager; journalctl --user -u $unit -b --no-pager -n 80"
      ;;
    activating|deactivating|reloading)
      doctor_report WARN "$label" "$unit is $state" \
        "Re-check with: systemctl --user status $unit --no-pager"
      ;;
    *)
      doctor_report UNKNOWN "$label" "systemd returned state '${state:-no response}' for $unit" \
        "Inspect with: systemctl --user status $unit --no-pager"
      ;;
  esac
}

run_doctor() {
  local system_state failed_units failed_names failed_count root_usage system_profile
  local root_fs home_fs

  DOCTOR_ERROR_COUNT=0
  DOCTOR_WARNING_COUNT=0
  DOCTOR_UNKNOWN_COUNT=0
  DOCTOR_SKIPPED_COUNT=0

  printf '\nStarforge system diagnostics (read-only)\n'
  printf '%s\n' '========================================='
  printf 'Host: %s\n' "$(hostname)"
  printf 'Date: %s\n' "$(date --iso-8601=seconds)"
  printf 'No services are restarted and no configuration is changed.\n\n'

  if [[ -e /etc/NIXOS ]]; then
    doctor_report OK "NixOS installation" "/etc/NIXOS is present"
  else
    doctor_report ERROR "NixOS installation" "/etc/NIXOS is missing" \
      "Confirm that this command is running on the intended NixOS installation."
  fi

  system_state="$(systemctl is-system-running 2>/dev/null || true)"
  case "$system_state" in
    running)
      doctor_report OK "Systemd manager" "system state is running"
      ;;
    degraded)
      doctor_report WARN "Systemd manager" "system state is degraded" \
        "Review failed units below, then inspect each relevant unit with systemctl status."
      ;;
    starting|stopping)
      doctor_report WARN "Systemd manager" "system state is $system_state" \
        "Wait until boot or shutdown completes, then run nixcfg doctor again."
      ;;
    *)
      doctor_report UNKNOWN "Systemd manager" "systemd returned state '${system_state:-no response}'" \
        "Check whether PID 1 is systemd and whether systemctl can reach the system manager."
      ;;
  esac

  if failed_units="$(systemctl --failed --no-legend --plain --no-pager 2>/dev/null)"; then
    if [[ -n "$failed_units" ]]; then
      failed_count="$(awk 'NF { count++ } END { print count + 0 }' <<< "$failed_units")"
      failed_names="$(awk 'NF { printf "%s%s", separator, $1; separator = ", " } END { print "" }' <<< "$failed_units")"
      doctor_report WARN "Failed systemd units" "$failed_count failed unit(s): $failed_names" \
        "Inspect with: systemctl --failed --no-pager; then use journalctl -u UNIT -b --no-pager -n 80."
    else
      doctor_report OK "Failed systemd units" "none"
    fi
  else
    doctor_report UNKNOWN "Failed systemd units" "systemd did not return the failed-unit list" \
      "Inspect with: systemctl --failed --no-pager"
  fi

  printf '\nRequired system services\n'
  doctor_check_system_unit "NetworkManager.service" "NetworkManager"
  doctor_check_system_unit "apparmor.service" "AppArmor"
  doctor_check_system_unit "usbguard.service" "USBGuard"
  doctor_check_system_unit "libvirtd.socket" "Libvirt management socket"

  if ! command -v findmnt >/dev/null 2>&1; then
    doctor_report UNKNOWN "Btrfs snapshot services" "findmnt is unavailable; filesystem types could not be checked"
  else
    root_fs="$(findmnt -n -o FSTYPE --target / 2>/dev/null || true)"
    home_fs="$(findmnt -n -o FSTYPE --mountpoint /home 2>/dev/null || true)"
    if [[ "$root_fs" == "btrfs" || "$home_fs" == "btrfs" ]]; then
      doctor_check_system_unit "prepare-btrfs-snapshots.service" "Btrfs snapshot preparation"
      doctor_check_system_unit "snapper-timeline.timer" "Snapper timeline timer"
      doctor_check_system_unit "snapper-cleanup.timer" "Snapper cleanup timer"
    else
      doctor_report SKIP "Btrfs snapshot services" "root and a separately mounted /home are not Btrfs; Snapper is intentionally disabled"
    fi
  fi

  printf '\nDesktop session\n'
  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    doctor_report SKIP "Wayland session" "no active Wayland session was detected; user desktop units were not checked"
  elif [[ -z "${XDG_RUNTIME_DIR:-}" || ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]]; then
    doctor_report UNKNOWN "Wayland user manager" "the Wayland session is present but its user systemd bus is unavailable" \
      "Check XDG_RUNTIME_DIR and the user systemd manager before inspecting desktop services."
  elif ! systemctl --user show-environment >/dev/null 2>&1; then
    doctor_report UNKNOWN "Wayland user manager" "systemctl could not contact the user manager" \
      "Inspect with: systemctl --user status"
  else
    doctor_report OK "Wayland user manager" "the user systemd manager is reachable"
    doctor_check_user_unit "noctalia.service" "Noctalia shell"
    doctor_check_user_unit "pipewire.service" "PipeWire"
    doctor_check_user_unit "pipewire-pulse.service" "PipeWire PulseAudio compatibility"
    doctor_check_user_unit "wireplumber.service" "WirePlumber"
  fi

  printf '\nStorage\n'
  root_usage="$(df -P --output=pcent / 2>/dev/null | awk 'NR == 2 { gsub(/%/, "", $1); print $1 }')"
  if [[ "$root_usage" =~ ^[0-9]+$ ]]; then
    if (( 10#$root_usage >= 95 )); then
      doctor_report ERROR "Root filesystem capacity" "$root_usage% used" \
        "Inspect with: df -h /; do not delete Nix generations or snapshots until you know what recovery points you need."
    elif (( 10#$root_usage >= 85 )); then
      doctor_report WARN "Root filesystem capacity" "$root_usage% used" \
        "Review disk usage with: df -h / and sudo nix-collect-garbage --dry-run."
    else
      doctor_report OK "Root filesystem capacity" "$root_usage% used"
    fi
  else
    doctor_report UNKNOWN "Root filesystem capacity" "df could not report root filesystem usage" \
      "Inspect with: df -h /"
  fi

  system_profile="/nix/var/nix/profiles/system"
  if [[ -e "$system_profile" ]]; then
    doctor_report OK "Current system generation" "$(readlink "$system_profile" 2>/dev/null || printf 'profile target is readable')"
  else
    doctor_report ERROR "Current system generation" "the system profile $system_profile is missing" \
      "Do not rebuild or edit boot entries blindly; inspect the NixOS profile and boot recovery path first."
  fi

  printf '\nSummary: %s error(s), %s warning(s), %s unknown, %s skipped.\n\n' \
    "$DOCTOR_ERROR_COUNT" "$DOCTOR_WARNING_COUNT" "$DOCTOR_UNKNOWN_COUNT" "$DOCTOR_SKIPPED_COUNT"

  if (( DOCTOR_ERROR_COUNT > 0 )); then
    return 1
  fi
  if (( DOCTOR_UNKNOWN_COUNT > 0 )); then
    return 2
  fi
  return 0
}


show_boot_analysis() {
  local failed=0

  if ! command -v systemd-analyze >/dev/null 2>&1; then
    printf 'systemd-analyze is unavailable; boot analysis cannot run.\n' >&2
    return 2
  fi

  printf '\nSystemd boot analysis (read-only)\n'
  printf '%s\n' '=================================='
  printf 'This command inspects the current boot; it does not change services or configuration.\n'

  printf '\nBoot timing\n'
  if ! systemd-analyze time --no-pager; then
    printf 'Could not read boot timing information.\n' >&2
    failed=1
  fi

  printf '\nSlowest units (top 15)\n'
  if ! systemd-analyze blame --no-pager | awk 'NR <= 15 { print }'; then
    printf 'Could not read systemd unit timing information.\n' >&2
    failed=1
  fi

  printf '\nCritical chain\n'
  if ! systemd-analyze critical-chain --no-pager; then
    printf 'Could not read the systemd critical chain.\n' >&2
    failed=1
  fi

  printf '\nInterpretation notes\n'
  printf '%s\n' \
    '- Blame durations are not additive: many units start in parallel.' \
    '- The critical chain shows one dependency path, not every source of delay.' \
    '- A slow unit is not automatically safe to disable or change.'

  return "$failed"
}
show_recovery() {
  local system_profile="/nix/var/nix/profiles/system"
  local current_generation

  printf '\nStarforge recovery guide (read-only)\n'
  printf '%s\n' '======================================'
  printf 'This command only inspects generation metadata and prints instructions.\n'
  printf 'It does not rebuild, switch, roll back, change boot entries, or restore files.\n\n'

  if [[ -e "$system_profile" ]]; then
    current_generation="$(readlink "$system_profile" 2>/dev/null || true)"
    printf 'Current system profile: %s\n' "${current_generation:-unavailable}"
  else
    printf 'Current system profile: unavailable (%s is missing)\n' "$system_profile"
  fi

  printf '\nAvailable system generations\n'
  if command -v nix-env >/dev/null 2>&1 && [[ -e "$system_profile" ]]; then
    if ! nix-env --list-generations --profile "$system_profile"; then
      printf 'Could not list system generations.\n'
    fi
  else
    printf 'nix-env or the system profile is unavailable; generation listing skipped.\n'
  fi

  cat <<'EOF'

Recovery paths

1. The system boots, but the latest generation is broken:
   From a TTY or terminal in the running NixOS system, run:
     sudo nixos-rebuild switch --rollback
   Then verify the result with:
     nixcfg doctor

2. The current generation does not reach a usable login:
   At the Limine boot menu, select an earlier NixOS generation. The configured
   menu retains up to five generations; it contains NixOS entries only.

3. A build or evaluation failed before activation:
   A failed build does not require a rollback because it has not activated a
   new generation. Read the complete error, inspect the configuration diff,
   and correct the source before retrying. Do not delete generations or run
   garbage collection as a first troubleshooting step.

4. Individual files need to be recovered:
   Snapper is configured only for Btrfs-backed root and/or separately mounted
   /home filesystems. When those snapshots are available, inspect them with:
     sudo snapper -c root list
     sudo snapper -c home list
   Root snapshots are under /.snapshots/<number>/snapshot/; home snapshots
   are under /home/.snapshots/<number>/snapshot/. A non-Btrfs filesystem has
   no Snapper snapshots. Restore individual files only after checking the
   source and destination. Snapshots share the source disk and are not a
   backup. Separate /nix and /var/log filesystems are not included.

5. The machine cannot boot any installed generation:
   Boot a NixOS installer ISO in UEFI mode. Unlock the target volume with its
   existing LUKS passphrase only when the root filesystem is encrypted. The
   repository's INSTALL.md describes mounting and automatic layout detection;
   its --install mode is a reinstall path, not a
   tested chroot-repair procedure. Do not format partitions, regenerate the
   hardware configuration, enroll new Secure Boot keys, or run install.sh
   --install unless a reinstall is explicitly intended.

Limitations

- A NixOS generation rollback restores the system closure, not arbitrary user
  data or external changes.
- Btrfs snapshots are enabled only for detected Btrfs root and/or separate
  /home filesystems. They are not backups and do not include separate /nix or
  /var/log filesystems.
- Secure Boot and the Limine EFI path are host-specific. Preserve known-good
  boot entries and key material; use nixcfg audit for the deeper read-only
  Secure Boot, AppArmor, USBGuard, and kernel checks.
EOF

  printf '\n'
}

check_formatting() {
  local nix_file
  local failed=0
  local -a nix_files

  mapfile -t nix_files < <(
    git ls-files --cached --others --exclude-standard -- '*.nix' ':!:hosts/workstation/hardware-configuration.nix'
  )

  for nix_file in "${nix_files[@]}"; do
    if ! diff -u "$nix_file" <(nixfmt < "$nix_file"); then
      printf 'Formatting differs: %s\n' "$nix_file" >&2
      failed=1
    fi
  done

  if (( failed != 0 )); then
    printf 'Run nix fmt to apply changes, then review the diff.\n' >&2
    return 1
  fi
}

run_checks() {
  local repo_root

  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -z "$repo_root" || ! -f "$repo_root/flake.nix" ]]; then
    printf 'nixcfg check must be run inside the NixOS configuration repository.\n' >&2
    return 2
  fi
  cd "$repo_root"

  printf '== Formatting check ==\n'
  check_formatting

  printf '\n== Statix and Deadnix ==\n'
  # shellcheck disable=SC2016
  nix develop --no-update-lock-file --accept-flake-config --command bash -euo pipefail -c '
    mapfile -t nix_files < <(
      git ls-files --cached --others --exclude-standard -- "*.nix" ":!:hosts/workstation/hardware-configuration.nix"
    )
    for nix_file in "${nix_files[@]}"; do
      statix check "$nix_file"
    done
    deadnix --fail "${nix_files[@]}"
  '

  printf '\n== Flake evaluation ==\n'
  nix flake check \
    --no-build \
    --no-update-lock-file \
    --accept-flake-config \
    --show-trace

  printf '\n== Full NixOS system build ==\n'
  nix build \
    --no-update-lock-file \
    --accept-flake-config \
    .#nixosConfigurations.workstation.config.system.build.toplevel \
    --no-link \
    --fallback \
    --print-build-logs

  printf '\nAll NixOS checks passed.\n'
}

case "${1:-status}" in
  status)
    show_status
    ;;
  doctor)
    run_doctor
    ;;
  boot)
    show_boot_analysis
    ;;
  recovery)
    show_recovery
    ;;
  audit)
    security_audit
    ;;
  check)
    run_checks
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
