#!/usr/bin/env bash

usage() {
  cat <<'EOF'
Usage:
  starforge status          Show a concise workstation health snapshot.
  starforge security-audit  Collect read-only P0 security diagnostics.
  starforge check           Run local formatting, lint, evaluation, and build checks.
EOF
}

show_status() {
  local cpu_model load_average failed_units system_generation

  printf '\nStarforge system status\n'
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

security_audit() {
  local path group device
  SUDO_AVAILABLE=false

  if (( EUID != 0 )); then
    if command -v sudo >/dev/null 2>&1 && sudo -v; then
      SUDO_AVAILABLE=true
    else
      printf 'Root-only checks will be skipped. Re-run with sudo for a complete audit.\n'
    fi
  fi

  printf '\nStarforge P0 security audit (read-only)\n'
  printf '%s\n' '======================================'
  printf 'Host: %s\n' "$(hostname)"
  printf 'Date: %s\n' "$(date --iso-8601=seconds)"
  printf 'Kernel: %s\n' "$(uname -r)"
  printf '\nThis command does not change firmware, keys, policies, or system configuration.\n'

  printf '\n== 1. Secure Boot and EFI ==\n'
  run_diagnostic user sbctl status
  run_diagnostic root sbctl verify
  run_diagnostic user bootctl status --no-pager
  run_diagnostic user fwupdmgr security

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

  printf '\n== End of read-only security audit ==\n'
  printf 'Review the output before changing Secure Boot, AppArmor, USBGuard, or kernel settings.\n\n'
}

check_formatting() {
  local nix_file
  local failed=0
  local -a nix_files

  mapfile -t nix_files < <(
    git ls-files --cached --others --exclude-standard -- '*.nix' ':!:hosts/starforge/hardware-configuration.nix'
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
    printf 'starforge check must be run inside the Starforge Git repository.\n' >&2
    return 2
  fi
  cd "$repo_root"

  printf '== Formatting check ==\n'
  check_formatting

  printf '\n== Statix and Deadnix ==\n'
  # shellcheck disable=SC2016
  nix develop --no-update-lock-file --accept-flake-config --command bash -euo pipefail -c '
    mapfile -t nix_files < <(
      git ls-files --cached --others --exclude-standard -- "*.nix" ":!:hosts/starforge/hardware-configuration.nix"
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

  printf '\n== Full Starforge system build ==\n'
  nix build \
    --no-update-lock-file \
    --accept-flake-config \
    .#nixosConfigurations.starforge.config.system.build.toplevel \
    --no-link \
    --fallback \
    --print-build-logs

  printf '\nAll Starforge checks passed.\n'
}

case "${1:-status}" in
  status)
    show_status
    ;;
  security-audit)
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
