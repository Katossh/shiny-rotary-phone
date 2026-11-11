#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPOSITORY_URL="https://github.com/Katossh/shiny-rotary-phone.git"
readonly HOST_NAME="workstation"
readonly INSTALL_ROOT="/mnt"
readonly INSTALL_REPO="/mnt/etc/nixos"

MODE="switch"
ASSUME_YES="false"

log() {
  printf '\n[nixcfg] %s\n' "$*"
}

warn() {
  printf '\n[nixcfg] WARNING: %s\n' "$*" >&2
}

die() {
  printf '\n[nixcfg] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--switch | --test | --install] [--yes]

Modes:
  --switch   Build and activate the workstation profile, making it the default
             boot generation. This is the default mode.
  --test     Build and temporarily activate the workstation profile without
             changing the default boot generation.
  --install  Install from a NixOS ISO into an already mounted /mnt. The script
             detects the mounted root/EFI filesystems and regenerates the host
             hardware configuration. It never partitions or formats disks.
  --yes      Skip the interactive confirmation prompt.
  --help     Show this help.

Run from the repository root as root, for example:
  sudo ./install.sh

Fresh installation from the NixOS ISO:
  git clone https://github.com/Katossh/shiny-rotary-phone.git /mnt/etc/nixos
  cd /mnt/etc/nixos
  ./install.sh --install
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

profile_eval() {
  local expression="$1"
  nix eval --raw "$REPO_DIR#nixosConfigurations.$HOST_NAME.config.$expression"
}

get_workstation_username() {
  local username

  username="$(profile_eval 'starforge.user.username')" \
    || die "Could not evaluate starforge.user.username for the workstation profile."
  [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
    || die "The evaluated workstation username is not a supported login name."

  printf '%s\n' "$username"
}

resolve_block_device() {
  local source="$1"

  # findmnt can append a Btrfs subvolume to SOURCE, for example
  # /dev/mapper/cryptroot[/@root]. The hardware configuration stores the
  # underlying block-device path instead.
  source="${source%%\\[*}"
  case "$source" in
    UUID=*) source="/dev/disk/by-uuid/${source#UUID=}" ;;
    LABEL=*) source="/dev/disk/by-label/${source#LABEL=}" ;;
    PARTUUID=*) source="/dev/disk/by-partuuid/${source#PARTUUID=}" ;;
  esac

  [[ -e "$source" ]] || die "Filesystem source cannot be resolved to a device: $source"
  source="$(readlink -f -- "$source")" \
    || die "Could not resolve filesystem source: $source"
  [[ -b "$source" ]] || die "Expected a block device for this mount, found: $source"

  printf '%s\n' "$source"
}

check_profile_mount() {
  local mount_point="$1"
  local actual_source actual_fs expected_source expected_fs
  local actual_device expected_device

  mountpoint -q "$mount_point" || die "Required filesystem is not mounted: $mount_point"

  actual_source="$(findmnt -n -o SOURCE --target "$mount_point")" \
    || die "Could not determine the active device mounted at $mount_point."
  actual_fs="$(findmnt -n -o FSTYPE --target "$mount_point")" \
    || die "Could not determine the active filesystem type at $mount_point."
  expected_source="$(profile_eval "fileSystems.\\"$mount_point\\".device")" \
    || die "The workstation profile does not define a device for $mount_point."
  expected_fs="$(profile_eval "fileSystems.\\"$mount_point\\".fsType")" \
    || die "The workstation profile does not define a filesystem type for $mount_point."

  [[ "$actual_fs" == "$expected_fs" ]] \
    || die "Filesystem mismatch at $mount_point: the profile expects $expected_fs, but the running system has $actual_fs."

  actual_device="$(resolve_block_device "$actual_source")"
  expected_device="$(resolve_block_device "$expected_source")"
  [[ "$actual_device" == "$expected_device" ]] \
    || die "Device mismatch at $mount_point: the profile expects $expected_source, but the active mount uses $actual_source."
}

check_current_profile_mounts() {
  require_command mountpoint
  require_command findmnt
  require_command readlink

  check_profile_mount "/"
  check_profile_mount "/boot"
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
  check_current_profile_mounts

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

check_install_mounts() {
  local root_source boot_source root_device boot_device root_fs boot_fs

  mountpoint -q "$INSTALL_ROOT" \
    || die "$INSTALL_ROOT is not a mount point. Mount the target root filesystem there first."
  mountpoint -q "$INSTALL_ROOT/boot" \
    || die "$INSTALL_ROOT/boot is not a separate mount point. Mount the target EFI partition there."

  root_source="$(findmnt -n -o SOURCE --target "$INSTALL_ROOT")" \
    || die "Could not determine the target root device mounted at $INSTALL_ROOT."
  boot_source="$(findmnt -n -o SOURCE --target "$INSTALL_ROOT/boot")" \
    || die "Could not determine the EFI device mounted at $INSTALL_ROOT/boot."
  root_fs="$(findmnt -n -o FSTYPE --target "$INSTALL_ROOT")" \
    || die "Could not determine the target root filesystem type."
  boot_fs="$(findmnt -n -o FSTYPE --target "$INSTALL_ROOT/boot")" \
    || die "Could not determine the EFI filesystem type."

  [[ "$boot_fs" == "vfat" ]] \
    || die "The EFI filesystem at $INSTALL_ROOT/boot must be FAT32/vfat, found: $boot_fs."
  root_device="$(resolve_block_device "$root_source")"
  boot_device="$(resolve_block_device "$boot_source")"
  [[ ! -e "/sys/class/block/${boot_device##*/}/dm/uuid" ]] \
    || die "The EFI filesystem is on a device-mapper device and is therefore not directly readable by UEFI. Mount an unencrypted EFI partition at $INSTALL_ROOT/boot."
  [[ "$root_device" != "$boot_device" ]] \
    || die "The target root and EFI filesystems resolve to the same block device. Mount a separate EFI partition at $INSTALL_ROOT/boot."

  log "Detected target root: $root_source ($root_fs)"
  log "Detected EFI mount: $boot_source ($boot_fs)"
  log "Additional mounted filesystems below $INSTALL_ROOT will be included automatically."
}

check_generated_mount() {
  local config_mount="$1"
  local target_mount="$2"
  local actual_source actual_fs expected_source expected_fs
  local actual_device expected_device

  actual_source="$(findmnt -n -o SOURCE --target "$target_mount")" \
    || die "Could not determine the detected device mounted at $target_mount."
  actual_fs="$(findmnt -n -o FSTYPE --target "$target_mount")" \
    || die "Could not determine the detected filesystem type at $target_mount."
  expected_source="$(profile_eval "fileSystems.\\"$config_mount\\".device")" \
    || die "The generated hardware configuration has no device for $config_mount."
  expected_fs="$(profile_eval "fileSystems.\\"$config_mount\\".fsType")" \
    || die "The generated hardware configuration has no filesystem type for $config_mount."

  [[ "$actual_fs" == "$expected_fs" ]] \
    || die "Generated configuration mismatch at $target_mount: expected $expected_fs, detected $actual_fs."
  actual_device="$(resolve_block_device "$actual_source")"
  expected_device="$(resolve_block_device "$expected_source")"
  [[ "$actual_device" == "$expected_device" ]] \
    || die "Generated configuration points $config_mount to $expected_source, but $target_mount is mounted from $actual_source."
}

check_secure_boot_keys() {
  local secure_boot
  local key_dir="$INSTALL_ROOT/var/lib/sbctl/keys"

  secure_boot="$(profile_eval 'boot.loader.limine.secureBoot.enable')" \
    || die "Could not evaluate the Limine Secure Boot setting."
  [[ "$secure_boot" == "true" ]] || return 0

  [[ -d "$key_dir" ]] \
    || die "This profile enables Limine Secure Boot, but no key directory exists at $key_dir. Back up and restore your existing sbctl keys there before installation. The installer will not generate or enroll Secure Boot keys."
  [[ -s "$key_dir/db/db.key" && -s "$key_dir/db/db.pem" ]] \
    || die "The target does not contain the expected sbctl DB private/public key pair under $key_dir/db. Restore the existing key set before installation. The installer will not generate or enroll Secure Boot keys."
}

run_install() {
  local username generated_config hardware_file hardware_tmp hardware_backup
  local hardware_validated="false"

  require_nixos
  require_command nixos-install
  require_command nixos-enter
  require_command nixos-generate-config
  require_command mountpoint
  require_command findmnt
  require_command readlink

  [[ "$REPO_DIR" == "$INSTALL_REPO" ]] \
    || die "For a fresh install, clone this repository to $INSTALL_REPO and run the script from there."
  [[ -d /sys/firmware/efi/efivars ]] \
    || die "This profile requires a UEFI boot. Boot the NixOS installer in UEFI mode."

  check_install_mounts
  warn "This installs the workstation profile to the mounted filesystems. It does not partition, format, create filesystems, modify LUKS keys, or enroll Secure Boot keys."
  warn "The profile still targets this workstation's AMD hardware. This mode adapts storage mounts, not the CPU/GPU or other host-specific modules."
  confirm "Detect the mounted layout, regenerate the host hardware configuration, and install NixOS to $INSTALL_ROOT?"

  hardware_file="$REPO_DIR/hosts/workstation/hardware-configuration.nix"
  [[ -f "$hardware_file" ]] || die "Missing host hardware configuration path: $hardware_file"
  check_secure_boot_keys

  generated_config="$(mktemp /run/nixcfg-hardware-configuration.XXXXXX)"
  hardware_backup="$(mktemp /run/nixcfg-hardware-backup.XXXXXX)"
  hardware_tmp="$(mktemp "${hardware_file}.XXXXXX")"
  cp -p -- "$hardware_file" "$hardware_backup"
  trap '
    if [[ "${hardware_validated:-false}" != "true" && -n "${hardware_backup:-}" && -f "$hardware_backup" ]]; then
      cp -p -- "$hardware_backup" "$hardware_tmp.restore" && mv -f -- "$hardware_tmp.restore" "$hardware_file"
    fi
    [[ -z "${generated_config:-}" ]] || rm -f -- "$generated_config"
    [[ -z "${hardware_backup:-}" ]] || rm -f -- "$hardware_backup"
    [[ -z "${hardware_tmp:-}" ]] || rm -f -- "$hardware_tmp"
  ' EXIT

  log "Detecting the target hardware and mounted filesystem layout..."
  nixos-generate-config --root "$INSTALL_ROOT" --show-hardware-config > "$generated_config" \
    || die "nixos-generate-config failed. The existing hardware configuration was not replaced."
  grep -Fq 'fileSystems."/"' "$generated_config" \
    || die "The generated configuration does not contain a root filesystem entry. Refusing to continue."
  grep -Fq 'fileSystems."/boot"' "$generated_config" \
    || die "The generated configuration does not contain an EFI mount entry. Refusing to continue."

  install -m 0644 "$generated_config" "$hardware_tmp"
  mv -f -- "$hardware_tmp" "$hardware_file"
  rm -f "$generated_config"
  generated_config=""

  # Verify the generated NixOS configuration resolves to the exact devices
  # already mounted under /mnt before allowing nixos-install to proceed.
  check_generated_mount "/" "$INSTALL_ROOT"
  check_generated_mount "/boot" "$INSTALL_ROOT/boot"
  username="$(get_workstation_username)"
  hardware_validated="true"

  log "Target root: $INSTALL_ROOT"
  log "Repository: $REPO_DIR"
  log "Generated hardware configuration: $hardware_file"
  log "Configured account: $username"

  nixos-install --flake "$REPO_DIR#$HOST_NAME"

  log "Set a password for the declared '$username' account before rebooting."
  nixos-enter --root "$INSTALL_ROOT" -c "passwd $username"

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
