#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPOSITORY_URL="https://github.com/Katossh/shiny-rotary-phone.git"
readonly HOST_NAME="workstation"
readonly INSTALL_ROOT="/mnt"
readonly INSTALL_REPO="/mnt/etc/nixos"

MODE="switch"
ASSUME_YES="false"
SCRIPT_DIR=""
REPO_DIR=""

log() { printf '\n[nixcfg] %s\n' "$*"; }
warn() { printf '\n[nixcfg] WARNING: %s\n' "$*" >&2; }
die() { printf '\n[nixcfg] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--switch | --test | --install] [--yes]

Modes:
  --switch   Build and activate the workstation profile, making it the default generation.
             This is the default mode for an already installed NixOS system.
  --test     Build and activate the workstation profile temporarily without changing the
             default boot generation.
  --install  Install the workstation profile into an already mounted /mnt from a NixOS
             installer environment. This mode never partitions or formats disks.
  --yes      Skip the interactive confirmation prompt.
  --help     Show this help.

Fresh installation:
  1. Mount the Btrfs root subvolume at /mnt.
  2. Mount the EFI System Partition (FAT32) at /mnt/boot.
  3. Mount any separate filesystems/subvolumes at their final paths
     (for example /mnt/home, /mnt/nix and /mnt/var/log).
  4. Clone this repository to /mnt/etc/nixos.
  5. Run: sudo ./install.sh --install

The installer detects the mounted filesystems and regenerates the host hardware
configuration. It does not partition, format, create subvolumes, or alter LUKS keys.
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
  [[ "$ID" == "nixos" ]] || die "This script must run from NixOS or the official NixOS installer environment."
}

resolve_repository() {
  local root remote
  require_command git

  root="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" \
    || die "Run this script from a Git clone of $REPOSITORY_URL."
  [[ "$root" == "$SCRIPT_DIR" ]] || die "The script must be in the root of the Git repository."
  [[ -f "$SCRIPT_DIR/flake.nix" && -f "$SCRIPT_DIR/flake.lock" ]] \
    || die "flake.nix or flake.lock is missing from the repository."

  remote="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null)" \
    || die "The repository has no 'origin' remote."
  case "$remote" in
    "$REPOSITORY_URL"|"https://github.com/Katossh/shiny-rotary-phone"|"git@github.com:Katossh/shiny-rotary-phone.git") ;;
    *) die "Unexpected Git origin: $remote. Expected $REPOSITORY_URL." ;;
  esac

  REPO_DIR="$root"
}

configure_nix() {
  require_command nix
  local nix_config
  nix_config="${NIX_CONFIG:-}"
  nix_config+=$'\n'"experimental-features = nix-command flakes"
  nix_config+=$'\n'"accept-flake-config = true"
  export NIX_CONFIG="$nix_config"
}

get_workstation_username() {
  local username
  username="$(nix eval --raw "$REPO_DIR#nixosConfigurations.$HOST_NAME.config.starforge.user.username")" \
    || die "Could not evaluate starforge.user.username for the workstation profile."
  [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
    || die "The evaluated workstation username is not a supported login name."
  printf '%s\n' "$username"
}

check_mount_type() {
  local target="$1"
  local expected_fs="$2"
  local actual_fs

  mountpoint -q "$target" || die "Required filesystem is not mounted at $target."
  actual_fs="$(findmnt -n -o FSTYPE --target "$target")"
  [[ "$actual_fs" == "$expected_fs" ]] \
    || die "Expected $target to use $expected_fs, found $actual_fs."
}

check_repository_profile() {
  [[ -f "$REPO_DIR/hosts/workstation/default.nix" ]] \
    || die "Missing host profile: $REPO_DIR/hosts/workstation/default.nix"
  [[ -f "$REPO_DIR/modules/nixos/boot.nix" ]] \
    || die "Missing boot module: $REPO_DIR/modules/nixos/boot.nix"
}

check_target_layout() {
  local root_subvolume

  require_command mountpoint
  require_command findmnt

  check_mount_type "$INSTALL_ROOT" "btrfs"
  check_mount_type "$INSTALL_ROOT/boot" "vfat"

  root_subvolume="$(findmnt -n -o FSROOT --target "$INSTALL_ROOT")"
  [[ -n "$root_subvolume" && "$root_subvolume" != "/" ]] \
    || die "Mount a Btrfs root subvolume (for example @) at $INSTALL_ROOT, not the top-level Btrfs volume. Snapper needs a root subvolume."

  [[ -d /sys/firmware/efi/efivars ]] \
    || die "This host profile requires UEFI. Boot the NixOS installer in UEFI mode."

  log "Detected target root: $(findmnt -n -o SOURCE --target "$INSTALL_ROOT")"
  log "Detected root subvolume: $root_subvolume"
  log "Detected EFI filesystem: $(findmnt -n -o SOURCE --target "$INSTALL_ROOT/boot")"
}

generate_hardware_configuration() {
  local hardware_file="$REPO_DIR/hosts/workstation/hardware-configuration.nix"
  local generated_file

  require_command nixos-generate-config
  require_command nix-instantiate
  require_command install
  require_command grep

  generated_file="$(mktemp)"
  if ! nixos-generate-config --root "$INSTALL_ROOT" --show-hardware-config > "$generated_file"; then
    rm -f "$generated_file"
    die "nixos-generate-config could not inspect the mounted target filesystems."
  fi

  if ! grep -Fq 'fileSystems."/"' "$generated_file"; then
    rm -f "$generated_file"
    die "Generated hardware configuration does not contain the mounted root filesystem."
  fi

  if ! grep -Fq 'fileSystems."/boot"' "$generated_file"; then
    rm -f "$generated_file"
    die "Generated hardware configuration does not contain the EFI filesystem mounted at /mnt/boot."
  fi

  if ! nix-instantiate --parse "$generated_file" >/dev/null; then
    rm -f "$generated_file"
    die "The generated hardware configuration is not valid Nix syntax."
  fi

  install -m 0644 "$generated_file" "$hardware_file"
  rm -f "$generated_file"

  log "Regenerated $hardware_file from the actual mounted filesystems."
  log "Partition UUIDs, device names, Btrfs subvolume names, and detected LUKS mappings are no longer hard-coded."
}

check_secure_boot_keys() {
  if grep -Eq 'secureBoot\.enable[[:space:]]*=[[:space:]]*true' "$REPO_DIR/modules/nixos/boot.nix"; then
    if [[ ! -d "$INSTALL_ROOT/var/lib/sbctl/keys" ]]; then
      warn "Limine Secure Boot signing is enabled, but no sbctl keys were found at $INSTALL_ROOT/var/lib/sbctl/keys."
      warn "Restore your existing /var/lib/sbctl directory before installation, or temporarily disable boot.loader.limine.secureBoot.enable in modules/nixos/boot.nix."
      warn "The firmware being set to 'Secure Boot: Disabled' does not recreate or back up the signing keys."
    fi
  fi
}

confirm() {
  local message="$1"
  local answer

  if [[ "$ASSUME_YES" == "true" ]]; then return 0; fi

  [[ -r /dev/tty ]] || die "No interactive terminal is available. Re-run with --yes after reviewing the operation."
  printf '\n%s [y/N] ' "$message" > /dev/tty
  IFS= read -r answer < /dev/tty || die "Could not read confirmation."
  [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]] \
    || die "Cancelled. No changes were made."
}

run_switch() {
  require_nixos
  require_command nixos-rebuild
  check_repository_profile
  require_command mountpoint
  require_command findmnt

  check_mount_type "/" "btrfs"
  check_mount_type "/boot" "vfat"

  log "Target profile: $HOST_NAME"
  log "Repository: $REPO_DIR"
  log "Mode: $MODE"
  if [[ "$MODE" == "test" ]]; then
    confirm "Build and temporarily activate the workstation profile? The default boot generation will not be changed."
  else
    confirm "Build and activate the workstation profile as the default system generation?"
  fi

  # nixos-rebuild builds the complete toplevel before activating it. A failed
  # evaluation or build therefore leaves the currently active generation intact.
  nixos-rebuild "$MODE" --flake "$REPO_DIR#$HOST_NAME" --show-trace

  log "NixOS $MODE completed."
  if [[ "$MODE" == "test" ]]; then
    log "This is a temporary activation. Use ./install.sh --switch after testing to make it the boot default."
  fi
}

run_install() {
  local username

  require_nixos
  require_command nixos-install
  require_command nixos-enter
  check_repository_profile
  check_target_layout

  [[ "$REPO_DIR" == "$INSTALL_REPO" ]] \
    || die "For a fresh install, clone this repository to $INSTALL_REPO and run the script from there."

  # Generate the machine-specific hardware configuration from the exact
  # filesystems mounted below /mnt. This discovers encrypted and unencrypted
  # roots, UUIDs, device paths, Btrfs subvolumes, and optional mountpoints.
  generate_hardware_configuration
  username="$(get_workstation_username)"
  check_secure_boot_keys

  log "Target root: $INSTALL_ROOT"
  log "Repository: $REPO_DIR"
  warn "This installs only to the existing mounted filesystems. It does not partition, format, create Btrfs subvolumes, change LUKS keys, or enroll Secure Boot keys."
  confirm "Install the workstation profile to $INSTALL_ROOT using the detected filesystem layout?"

  nixos-install --root "$INSTALL_ROOT" --flake "$REPO_DIR#$HOST_NAME"

  log "Set a password for the declared '$username' account before rebooting."
  nixos-enter --root "$INSTALL_ROOT" -c "passwd $username"

  log "Installation completed. Review the installer output, then reboot when ready."
}

main() {
  local arg
  SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"

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
