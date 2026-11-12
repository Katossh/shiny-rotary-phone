#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPOSITORY_URL="https://github.com/Katossh/shiny-rotary-phone.git"
readonly HOST_NAME="workstation"
readonly INSTALL_ROOT="/mnt"
readonly INSTALL_REPO="/mnt/etc/nixos"

MODE="auto"
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
  --test     Build and activate the workstation profile temporarily without changing the
             default boot generation.
  --install  Install the workstation profile into an already mounted /mnt from a NixOS
             installer environment. This mode never partitions or formats disks.
  --yes      Skip interactive confirmation prompts.
  --help     Show this help.

Fresh installation:
  1. Mount the root filesystem at /mnt (Btrfs, ext4, or XFS).
  2. Mount the EFI System Partition (FAT32) at /mnt/boot.
  3. Mount any separate filesystems/subvolumes at their final paths
     (for example /mnt/home, /mnt/nix and /mnt/var/log).
  4. Clone this repository to /mnt/etc/nixos.
  5. Run: sudo ./install.sh --install

With no mode specified, the script selects --install when the clone is at
/mnt/etc/nixos; otherwise it selects --switch. The installer detects the
mounted filesystems. It copies /etc/nixos/hardware-configuration.nix when
available; otherwise it asks before generating a local hardware configuration.
It does not partition, format, create subvolumes, or alter LUKS keys.
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
  username="$(nix eval --raw "path:$REPO_DIR#nixosConfigurations.$HOST_NAME.config.starforge.user.username")" \
    || die "Could not evaluate starforge.user.username for the workstation profile."
  [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
    || die "The evaluated workstation username is not a supported login name."
  printf '%s\n' "$username"
}

# Home Manager creates links as the target user. Check only the parent
# directories of files declared by the evaluated Home Manager profile, so a
# foreign-owned directory elsewhere in the home does not cause a false alarm.
check_home_manager_target_permissions() {
  local username="$1"
  local home_dir="/home/$username"
  local managed_paths relative_path parent owner_uid owner_gid mode group

  require_command runuser
  require_command stat

  [[ -d "$home_dir" ]] || die "The configured Home Manager home directory does not exist: $home_dir"

  managed_paths="$(
    nix eval --raw \
      "path:$REPO_DIR#nixosConfigurations.$HOST_NAME.config.home-manager.users.\"$username\".home.file" \
      --apply '
        files:
        builtins.concatStringsSep "\n" (
          map (file: file.target)
            (builtins.filter (file: file.enable) (builtins.attrValues files))
        )
      '
  )" || die "Could not enumerate the Home Manager-managed targets for $username."

  [[ -n "$managed_paths" ]] || return 0

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    case "$relative_path" in
      /*|..|../*|*/../*|*/..)
        die "Home Manager returned an unexpected non-relative target path: $relative_path"
        ;;
    esac

    parent="$(dirname -- "$home_dir/$relative_path")"
    while [[ "$parent" == "$home_dir/"* ]]; do
      if [[ -d "$parent" ]] && ! runuser -u "$username" -- test -w "$parent" -a -x "$parent"; then
        read -r owner_uid owner_gid mode < <(stat -c '%u %g %a' -- "$parent")
        group="$(id -gn "$username")"
        die "Home Manager cannot write to $parent (owner UID:GID $owner_uid:$owner_gid, mode $mode). Restore ownership of this directory only with: sudo chown '$username:$group' '$parent'. Do not use recursive chown. If ownership changes again, inspect rootless Podman bind mounts for the ':U' option."
      fi
      parent="$(dirname -- "$parent")"
    done
  done <<< "$managed_paths"
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

check_supported_root_fs() {
  local target="$1"
  local actual_fs

  mountpoint -q "$target" || die "Root filesystem is not mounted at $target."
  actual_fs="$(findmnt -n -o FSTYPE --target "$target")"
  case "$actual_fs" in
    btrfs|ext4|xfs) ;;
    *) die "Unsupported root filesystem at $target: $actual_fs. Supported types: btrfs, ext4, xfs." ;;
  esac
  printf '%s\n' "$actual_fs"
}

check_repository_profile() {
  [[ -f "$REPO_DIR/hosts/workstation/default.nix" ]] \
    || die "Missing host profile: $REPO_DIR/hosts/workstation/default.nix"
  [[ -f "$REPO_DIR/modules/nixos/boot.nix" ]] \
    || die "Missing boot module: $REPO_DIR/modules/nixos/boot.nix"
}

check_target_layout() {
  local root_fs

  require_command mountpoint
  require_command findmnt

  root_fs="$(check_supported_root_fs "$INSTALL_ROOT")"
  check_mount_type "$INSTALL_ROOT/boot" "vfat"

  [[ -d /sys/firmware/efi/efivars ]] \
    || die "This host profile requires UEFI. Boot the NixOS installer in UEFI mode."

  log "Detected target root: $(findmnt -n -o SOURCE --target "$INSTALL_ROOT") ($root_fs)"
  log "Detected EFI filesystem: $(findmnt -n -o SOURCE --target "$INSTALL_ROOT/boot")"
  if [[ "$root_fs" == "btrfs" ]]; then
    log "Detected Btrfs root: $(findmnt -n -o FSROOT --target "$INSTALL_ROOT")"
  fi
}

validate_hardware_configuration() {
  local hardware_file="$1"

  if ! grep -Fq 'fileSystems."/"' "$hardware_file"; then
    warn "Hardware configuration does not contain the root filesystem."
    return 1
  fi

  if ! grep -Fq 'fileSystems."/boot"' "$hardware_file"; then
    warn "Hardware configuration does not contain the /boot filesystem."
    return 1
  fi

  if ! nix-instantiate --parse "$hardware_file" >/dev/null; then
    warn "Hardware configuration is not valid Nix syntax: $hardware_file"
    return 1
  fi
}

ensure_hardware_configuration() {
  local target_root="$1"
  local source_file="/etc/nixos/hardware-configuration.nix"
  local host_dir="$REPO_DIR/hosts/workstation"
  local hardware_file="$host_dir/hardware-configuration.nix"
  local temporary_file

  require_command grep
  require_command nix-instantiate
  require_command install
  require_command chmod
  require_command mv
  require_command mktemp

  if [[ -e "$source_file" && ! -f "$source_file" ]]; then
    die "$source_file exists but is not a regular file."
  fi

  # Prefer the currently installed NixOS hardware configuration when present.
  # This intentionally avoids regenerating stable device and filesystem data.
  if [[ -f "$source_file" ]]; then
    if [[ "$source_file" -ef "$hardware_file" ]]; then
      validate_hardware_configuration "$hardware_file" \
        || die "The existing hardware configuration is invalid."
      log "Using the existing hardware configuration at $source_file."
      return
    fi

    temporary_file="$(mktemp "$host_dir/.hardware-configuration.nix.XXXXXX")"
    if ! install -m 0644 -- "$source_file" "$temporary_file"; then
      rm -f -- "$temporary_file"
      die "Could not copy $source_file."
    fi
    if ! validate_hardware_configuration "$temporary_file"; then
      rm -f -- "$temporary_file"
      die "The existing hardware configuration at $source_file is invalid."
    fi
    if ! mv -f -- "$temporary_file" "$hardware_file"; then
      rm -f -- "$temporary_file"
      die "Could not place the copied hardware configuration in $hardware_file."
    fi

    log "Copied existing hardware configuration from $source_file."
    return
  fi

  # Reuse a previously prepared local copy when /etc/nixos is unavailable.
  if [[ -e "$hardware_file" ]]; then
    [[ -f "$hardware_file" ]] || die "$hardware_file exists but is not a regular file."
    validate_hardware_configuration "$hardware_file" \
      || die "The local hardware configuration is invalid."
    log "Using the existing local hardware configuration at $hardware_file."
    return
  fi

  require_command nixos-generate-config
  confirm "No existing hardware configuration was found. Generate one for $target_root from its currently mounted filesystems? This creates $hardware_file."

  temporary_file="$(mktemp "$host_dir/.hardware-configuration.nix.XXXXXX")"
  if [[ "$target_root" == "/" ]]; then
    if ! nixos-generate-config --show-hardware-config > "$temporary_file"; then
      rm -f -- "$temporary_file"
      die "nixos-generate-config could not inspect the current root filesystem."
    fi
  else
    if ! nixos-generate-config --root "$target_root" --show-hardware-config > "$temporary_file"; then
      rm -f -- "$temporary_file"
      die "nixos-generate-config could not inspect the mounted target filesystems."
    fi
  fi

  if ! validate_hardware_configuration "$temporary_file"; then
    rm -f -- "$temporary_file"
    die "The generated hardware configuration is incomplete or invalid."
  fi

  if ! chmod 0644 "$temporary_file"; then
    rm -f -- "$temporary_file"
    die "Could not set permissions on the generated hardware configuration."
  fi
  if ! mv -f -- "$temporary_file" "$hardware_file"; then
    rm -f -- "$temporary_file"
    die "Could not place the generated hardware configuration in $hardware_file."
  fi

  log "Generated the local hardware configuration from the filesystems mounted under $target_root."
  log "The file is Git-ignored and will not be included in repository commits."
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
  local username

  require_nixos
  require_command nixos-rebuild
  check_repository_profile
  require_command mountpoint
  require_command findmnt

  check_supported_root_fs "/"
  check_mount_type "/boot" "vfat"
  ensure_hardware_configuration "/"

  username="$(get_workstation_username)"
  check_home_manager_target_permissions "$username"

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
  nixos-rebuild "$MODE" --flake "path:$REPO_DIR#$HOST_NAME" --show-trace

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

  # Use the existing /etc/nixos hardware configuration when available.
  # Otherwise, ask before generating one from the filesystems mounted below /mnt.
  ensure_hardware_configuration "$INSTALL_ROOT"
  username="$(get_workstation_username)"
  check_secure_boot_keys

  log "Target root: $INSTALL_ROOT"
  log "Repository: $REPO_DIR"
  warn "This installs only to the existing mounted filesystems. It does not partition, format, create Btrfs subvolumes, change LUKS keys, or enroll Secure Boot keys."
  confirm "Install the workstation profile to $INSTALL_ROOT using the detected filesystem layout?"

  nixos-install --root "$INSTALL_ROOT" --flake "path:$REPO_DIR#$HOST_NAME"

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
        [[ "$MODE" == "auto" ]] || die "Choose only one mode."
        MODE="switch"
        ;;
      --test)
        [[ "$MODE" == "auto" ]] || die "Choose only one mode."
        MODE="test"
        ;;
      --install)
        [[ "$MODE" == "auto" ]] || die "Choose only one mode."
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

  if [[ "$MODE" == "auto" ]]; then
    if [[ "$REPO_DIR" == "$INSTALL_REPO" ]]; then
      MODE="install"
    else
      MODE="switch"
    fi
  fi

  configure_nix

  if [[ "$MODE" == "install" ]]; then
    run_install
  else
    run_switch
  fi
}

main "$@"
