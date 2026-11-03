#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPOSITORY_URL="https://github.com/Katossh/shiny-rotary-phone.git"
readonly HOST_NAME="starforge"
readonly ROOT_LUKS_UUID="fb18dd0b-4f76-449f-9d00-67cc9d49b4ee"
readonly BOOT_FS_UUID="FD77-5C81"
readonly WINDOWS_ESP_PARTUUID="68a6f3c1-1eee-4845-8c3e-7108cec34c4a"
readonly INSTALL_ROOT="/mnt"
readonly INSTALL_REPO="/mnt/etc/nixos/starforge"

MODE="switch"
ASSUME_YES="false"

log() {
  printf '\n[starforge] %s\n' "$*"
}

warn() {
  printf '\n[starforge] WARNING: %s\n' "$*" >&2
}

die() {
  printf '\n[starforge] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--switch | --test | --install] [--yes]

Modes:
  --switch   Build and activate Starforge, making it the default generation.
             This is the default mode.
  --test     Build and activate Starforge temporarily without changing the
             default boot generation.
  --install  Install Starforge into an already mounted /mnt from a NixOS
             installer environment. This mode never partitions or formats disks.
  --yes      Skip the interactive confirmation prompt.
  --help     Show this help.

Run as root, for example:
  sudo ./install.sh
USAGE
}

require_root() {
  [[ "$EUID" -eq 0 ]] || die "Run this script as root (for example: sudo ./install.sh)."
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_nixos() {
  [[ -r /etc/os-release ]] || die "Cannot identify the running operating system."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "nixos" ]] || die "This script must run from NixOS or the official NixOS installer environment."
}

resolve_repository() {
  local root remote

  require_command git
  root="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" \
    || die "Run this script from a Git clone of ${REPOSITORY_URL}."
  [[ "$root" == "$SCRIPT_DIR" ]] || die "The script must be in the root of the Git repository."
  [[ -f "$SCRIPT_DIR/flake.nix" && -f "$SCRIPT_DIR/flake.lock" ]] \
    || die "flake.nix or flake.lock is missing from the repository."

  remote="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null)" \
    || die "The repository has no 'origin' remote."
  case "$remote" in
    "$REPOSITORY_URL"|"https://github.com/Katossh/shiny-rotary-phone"|"git@github.com:Katossh/shiny-rotary-phone.git") ;;
    *) die "Unexpected Git origin: ${remote}. Expected ${REPOSITORY_URL}." ;;
  esac

  REPO_DIR="$root"
}

configure_nix() {
  require_command nix
  # The flake is pinned by flake.lock. This enables flakes on a minimal NixOS
  # install and accepts the public Noctalia cache settings declared by flake.nix.
  local nix_config="${NIX_CONFIG:-}"
  nix_config+=$'\n'"experimental-features = nix-command flakes"
  nix_config+=$'\n'"accept-flake-config = true"
  export NIX_CONFIG="${nix_config}"
}

check_profile_files() {
  local hardware_file="${REPO_DIR}/hosts/starforge/hardware-configuration.nix"

  [[ -f "$hardware_file" ]] || die "Missing Starforge hardware configuration: ${hardware_file}"
  grep -Fq "$ROOT_LUKS_UUID" "$hardware_file" \
    || die "The committed hardware configuration no longer matches the expected encrypted-root UUID."
  grep -Fq "$BOOT_FS_UUID" "$hardware_file" \
    || die "The committed hardware configuration no longer matches the expected /boot UUID."
  grep -Fq "$WINDOWS_ESP_PARTUUID" "$REPO_DIR/modules/nixos/boot.nix" \
    || die "The Limine Windows entry no longer matches the expected Windows ESP GUID."
}

check_expected_devices() {
  local path
  local -a devices=(
    "/dev/disk/by-uuid/$ROOT_LUKS_UUID"
    "/dev/disk/by-uuid/$BOOT_FS_UUID"
    "/dev/disk/by-partuuid/$WINDOWS_ESP_PARTUUID"
  )

  for path in "${devices[@]}"; do
    [[ -e "$path" ]] || die "Expected Starforge disk identifier is missing: $path. Refusing to apply this machine-specific profile."
  done

  [[ -b /dev/mapper/cryptroot ]] \
    || die "The encrypted root mapping /dev/mapper/cryptroot is not open."
}

check_mount() {
  local target="$1"
  local expected_fs="$2"
  local actual_fs

  mountpoint -q "$target" || die "Required filesystem is not mounted: $target"
  actual_fs="$(findmnt -n -o FSTYPE --target "$target")"
  [[ "$actual_fs" == "$expected_fs" ]] \
    || die "Expected $target to be $expected_fs, found $actual_fs."
}

check_btrfs_subvolume() {
  local target="$1"
  local expected_subvolume="$2"
  local actual_subvolume

  actual_subvolume="$(findmnt -n -o FSROOT --target "$target")"
  [[ "$actual_subvolume" == "/$expected_subvolume" ]] \
    || die "Expected $target to be Btrfs subvolume $expected_subvolume, found $actual_subvolume."
}

check_encrypted_root_mapping() {
  local target="$1"
  local source

  source="$(findmnt -n -o SOURCE --target "$target")"
  case "$source" in
    /dev/mapper/cryptroot|/dev/mapper/cryptroot\[*\]) ;;
    *) die "Expected $target to be mounted from /dev/mapper/cryptroot, found $source." ;;
  esac
}

check_boot_uuid() {
  local target="$1"
  local actual_uuid

  actual_uuid="$(findmnt -n -o UUID --target "$target")"
  [[ "$actual_uuid" == "$BOOT_FS_UUID" ]] \
    || die "Expected $target to use filesystem UUID $BOOT_FS_UUID, found $actual_uuid."
}

confirm() {
  local message="$1"
  local answer

  if [[ "$ASSUME_YES" == "true" ]]; then
    return 0
  fi

  [[ -r /dev/tty ]] || die "No interactive terminal is available. Re-run with --yes after reviewing the operation."
  printf '\n%s [y/N] ' "$message" > /dev/tty
  IFS= read -r answer < /dev/tty || die "Could not read confirmation."
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]] \
    || die "Cancelled. No changes were made."
}

run_switch() {
  require_nixos
  require_command nixos-rebuild
  require_command mountpoint
  require_command findmnt
  check_profile_files
  check_expected_devices

  check_mount "/" "btrfs"
  check_btrfs_subvolume "/" "@root"
  check_encrypted_root_mapping "/"
  check_mount "/home" "btrfs"
  check_btrfs_subvolume "/home" "@home"
  check_mount "/nix" "btrfs"
  check_btrfs_subvolume "/nix" "@nix"
  check_mount "/var/log" "btrfs"
  check_btrfs_subvolume "/var/log" "@var-log"
  check_mount "/boot" "vfat"
  check_boot_uuid "/boot"

  log "Target profile: $HOST_NAME"
  log "Repository: $REPO_DIR"
  log "Mode: $MODE"
  if [[ "$MODE" == "test" ]]; then
    confirm "Build and temporarily activate Starforge? The default boot generation will not be changed."
  else
    confirm "Build and activate Starforge as the default system generation?"
  fi

  # nixos-rebuild builds the complete toplevel before activating it. A failed
  # evaluation or build therefore leaves the currently active generation intact.
  nixos-rebuild "$MODE" --flake "$REPO_DIR#$HOST_NAME" --show-trace

  log "Starforge $MODE completed."
  if [[ "$MODE" == "test" ]]; then
    log "This is a temporary activation. Use ./install.sh --switch after testing to make it the boot default."
  fi
}

run_install() {
  require_nixos
  require_command nixos-install
  require_command nixos-enter
  require_command mountpoint
  require_command findmnt

  [[ "$REPO_DIR" == "$INSTALL_REPO" ]] \
    || die "For a fresh install, clone this repository to $INSTALL_REPO and run the script from there."
  [[ -d /sys/firmware/efi/efivars ]] \
    || die "Starforge requires a UEFI boot. Boot the NixOS installer in UEFI mode."
  check_profile_files
  check_expected_devices

  check_mount "$INSTALL_ROOT" "btrfs"
  check_btrfs_subvolume "$INSTALL_ROOT" "@root"
  check_encrypted_root_mapping "$INSTALL_ROOT"
  check_mount "$INSTALL_ROOT/home" "btrfs"
  check_btrfs_subvolume "$INSTALL_ROOT/home" "@home"
  check_mount "$INSTALL_ROOT/nix" "btrfs"
  check_btrfs_subvolume "$INSTALL_ROOT/nix" "@nix"
  check_mount "$INSTALL_ROOT/var/log" "btrfs"
  check_btrfs_subvolume "$INSTALL_ROOT/var/log" "@var-log"
  check_mount "$INSTALL_ROOT/boot" "vfat"
  check_boot_uuid "$INSTALL_ROOT/boot"

  log "Target root: $INSTALL_ROOT"
  log "Repository: $REPO_DIR"
  warn "This installs only to the existing mounted Starforge layout. It does not partition, format, create filesystems, or change LUKS keys."
  confirm "Install NixOS from this Starforge flake to /mnt?"

  nixos-install --flake "$REPO_DIR#$HOST_NAME"

  log "Set a password for the declared katossh account before rebooting."
  nixos-enter --root "$INSTALL_ROOT" -c 'passwd katossh'

  log "Installation completed. Review the installer output, then reboot when ready."
}

main() {
  local arg

  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  REPO_DIR=""

  while (($#)); do
    arg="$1"
    shift
    case "$arg" in
      --switch)
        [[ "$MODE" == "switch" ]] || die "Choose only one mode."
        MODE="switch"
        ;;
      --test)
        [[ "$MODE" == "switch" ]] || die "Choose only one mode."
        MODE="test"
        ;;
      --install)
        [[ "$MODE" == "switch" ]] || die "Choose only one mode."
        MODE="install"
        ;;
      --yes)
        ASSUME_YES="true"
        ;;
      --help|-h)
        usage
        return 0
        ;;
      *)
        die "Unknown argument: $arg. Use --help for usage."
        ;;
    esac
  done

  require_root
  resolve_repository
  configure_nix

  if [[ "$MODE" == "install" ]]; then
    run_install
  else
    run_switch
  fi
}

main "$@"
