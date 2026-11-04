#!/usr/bin/env bash

usage() {
  cat <<'EOF'
Usage:
  starforge status   Show a concise workstation health snapshot.
  starforge check    Run local formatting, lint, evaluation, and build checks.
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
    printf 'Run nix fmt to apply formatting, then review the diff.\n' >&2
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
