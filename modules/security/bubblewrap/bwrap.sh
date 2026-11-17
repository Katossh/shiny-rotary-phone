# This file is embedded into a pkgs.writeShellApplication derivation.

usage() {
  cat <<'USAGE'
Usage:
  bwrap dev [--network] [--cargo-cache] [--home] [PROJECT] -- COMMAND [ARG...]
  bwrap network [--workspace DIR] -- COMMAND [ARG...]
  bwrap isolated [--workspace DIR] -- COMMAND [ARG...]
  bwrap help

Profiles:
  dev       Expose PROJECT read-write. Network is disabled unless --network is set.
            --cargo-cache also exposes ~/.cargo/registry read-write.
            --home exposes the host home read-write except protected credential
            and browser-data paths. PROJECT may be omitted with --home.
  network   Share the host network. An optional workspace is read-only.
  isolated  Disable networking. An optional workspace is read-only.

The host home directory, user-session sockets, and host runtime directories are
never mounted unless dev is explicitly invoked with --home. Only Nix-store
executables are available through PATH.
Use `bubblewrap` to invoke the underlying Bubblewrap binary directly.
USAGE
}

die() {
  printf 'bwrap: %s\n' "$*" >&2
  exit 2
}

[[ $# -gt 0 ]] || {
  usage >&2
  exit 2
}

profile=$1
shift
network_enabled=0
workspace_input=
workspace=
cargo_cache_enabled=0
home_access_enabled=0

case "$profile" in
  help|-h|--help)
    usage
    exit 0
    ;;
  dev)
    while [[ ${1-} == --* ]]; do
      case "$1" in
        --network)
          network_enabled=1
          shift
          ;;
        --cargo-cache)
          cargo_cache_enabled=1
          shift
          ;;
        --home)
          home_access_enabled=1
          shift
          ;;
        *) break ;;
      esac
    done
    if [[ ${1-} != -- && -n ${1-} ]]; then
      workspace_input=$1
      shift
    elif [[ "$home_access_enabled" -eq 0 ]]; then
      die "dev requires a project directory unless --home is set"
    fi
    ;;
  network)
    while [[ ${1-} == --* ]]; do
      case "$1" in
        --workspace)
          [[ $# -ge 2 ]] || die "--workspace requires a directory"
          workspace_input=$2
          shift 2
          ;;
        *) break ;;
      esac
    done
    network_enabled=1
    ;;
  isolated)
    while [[ ${1-} == --* ]]; do
      case "$1" in
        --workspace)
          [[ $# -ge 2 ]] || die "--workspace requires a directory"
          workspace_input=$2
          shift 2
          ;;
        *) break ;;
      esac
    done
    ;;
  *)
    usage >&2
    die "unknown profile: $profile"
    ;;
esac

[[ ${1-} == -- ]] || die "expected '--' before the command"
shift
[[ $# -gt 0 ]] || die "no command was supplied"

home_real=
protected_home_relatives=(
  .ssh
  .gnupg
  .aws
  .azure
  .kube
  .docker
  .password-store
  .pki
  .mozilla
  .netrc
  .git-credentials
  .npmrc
  .pypirc
  .pgpass
  .my.cnf
  .cargo/credentials
  .cargo/credentials.toml
  .config/gh
  .config/gcloud
  .config/rclone
  .config/sops
  .config/containers
  .config/1Password
  .config/Bitwarden
  .config/keepassxc
  .config/keepass
  .config/BraveSoftware
  .config/google-chrome
  .config/chromium
  .config/AmneziaVPN
  .config/amnezia
  .config/wireguard
  .config/Nextcloud
  .local/share/keyrings
  .local/share/TelegramDesktop
)

if [[ -n ${HOME:-} ]]; then
  home_real="$(realpath -e -- "$HOME" 2>/dev/null)" || die "cannot resolve HOME"
fi

if [[ -n "$workspace_input" ]]; then
  [[ -d "$workspace_input" ]] || die "workspace is not a directory: $workspace_input"
  workspace="$(cd -- "$workspace_input" && pwd -P)" || die "cannot resolve workspace: $workspace_input"

  [[ "$workspace" != "/" ]] || die "refusing to expose the host root directory"

  for protected in /nix /etc /run /proc /sys /dev /boot /var /root; do
    if [[ "$workspace" == "$protected" || "$workspace" == "$protected/"* ]]; then
      die "refusing to expose a protected host path as a workspace: $workspace"
    fi
  done

  if [[ -n "$home_real" ]]; then
    [[ "$workspace" != "$home_real" && "$home_real" != "$workspace/"* ]] || die "refusing to expose the host home directory or a directory containing it"

    for relative_path in "${protected_home_relatives[@]}"; do
      protected_path="$home_real/$relative_path"
      if [[ "$workspace" == "$protected_path" || "$workspace" == "$protected_path/"* || "$protected_path" == "$workspace/"* ]]; then
        die "workspace overlaps a protected credential or application-data path: $protected_path"
      fi
    done
  fi
fi

if [[ "$home_access_enabled" -eq 1 ]]; then
  [[ -n "$home_real" && -d "$home_real" ]] || die "--home requires a resolvable host home directory"
fi

# Keep only PATH entries that resolve into the immutable Nix store. This makes
# host-installed Nix tools available without mounting /run/current-system or
# the user's profile directory into the sandbox.
sandbox_path=
IFS=: read -r -a host_path_entries <<< "${PATH:-}"
for path_entry in "${host_path_entries[@]}"; do
  [[ -n "$path_entry" && -d "$path_entry" ]] || continue
  case "$path_entry" in
    /run/wrappers|/run/wrappers/*) continue ;;
  esac

  resolved_path="$(realpath -e -- "$path_entry" 2>/dev/null)" || continue
  [[ "$resolved_path" == /nix/store/* && -d "$resolved_path" ]] || continue

  case ":$sandbox_path:" in
    *":$resolved_path:"*) ;;
    *) sandbox_path="${sandbox_path:+$sandbox_path:}$resolved_path" ;;
  esac
done

[[ -n "$sandbox_path" ]] || die "no usable Nix-store directories were found in PATH"

requested_command=$1
shift
sandbox_command=$requested_command

if [[ "$requested_command" == */* ]]; then
  if [[ "$requested_command" == /* ]]; then
    command_source=$requested_command
  else
    [[ -n "$workspace" ]] || die "relative executable paths require --workspace (or a dev project)"
    command_source="$workspace/$requested_command"
  fi

  command_real="$(realpath -e -- "$command_source" 2>/dev/null)" || die "cannot resolve executable: $requested_command"
  [[ -x "$command_real" ]] || die "not executable: $requested_command"

  if [[ -n "$workspace" && "$command_real" == "$workspace/"* ]]; then
    sandbox_command="/workspace/${command_real#"$workspace"/}"
  elif [[ "$command_real" == /nix/store/* ]]; then
    sandbox_command=$command_real
  else
    die "executable must be inside the workspace or /nix/store: $requested_command"
  fi
else
  host_command="$(command -v "$requested_command" 2>/dev/null)" || die "command not found in host PATH: $requested_command"
  command_real="$(realpath -e -- "$host_command" 2>/dev/null)" || die "cannot resolve command: $requested_command"
  [[ "$command_real" == /nix/store/* ]] || die "command does not resolve into /nix/store: $requested_command"
fi

bwrap_args=(
  --unshare-user
  --unshare-ipc
  --unshare-pid
  --unshare-uts
  --unshare-cgroup-try
  --disable-userns
  --die-with-parent
  --new-session
  --hostname bwrap
  --cap-drop ALL
  --dir /nix
  --ro-bind /nix/store /nix/store
  --proc /proc
  --dev /dev
  --tmpfs /tmp
  --dir /tmp/home
  --dir /tmp/cache
  --dir /tmp/config
  --dir /tmp/data
  --dir /tmp/cargo-home
  --dir /tmp/cargo-home/registry
  --dir /etc
  --dir /workspace
  --dir /bin
  --symlink "$BASH_BIN" /bin/bash
  --symlink "$BASH_BIN" /bin/sh
  --dir /usr
  --dir /usr/bin
  --symlink "$ENV_BIN" /usr/bin/env
  --clearenv
  --unsetenv PWD
  --setenv PATH "$sandbox_path"
  --setenv HOME /tmp/home
  --setenv TMPDIR /tmp
  --setenv XDG_CACHE_HOME /tmp/cache
  --setenv XDG_CONFIG_HOME /tmp/config
  --setenv XDG_DATA_HOME /tmp/data
  --setenv CARGO_HOME /tmp/cargo-home
  --setenv LANG C.UTF-8
  --setenv LC_ALL C.UTF-8
)

if [[ "$network_enabled" -eq 0 ]]; then
  bwrap_args+=(--unshare-net)
fi

# These files provide basic user/group lookup. The home directory and all
# credential-bearing configuration remain absent from the sandbox.
for etc_file in passwd group; do
  if [[ -r "/etc/$etc_file" ]]; then
    bwrap_args+=(--ro-bind "/etc/$etc_file" "/etc/$etc_file")
  fi
done

# A read-only CA bundle is useful for network-enabled commands and harmless
# for offline profiles. Resolve symlinks on the host before bind-mounting.
if [[ -d /etc/ssl/certs ]]; then
  bwrap_args+=(--dir /etc/ssl)
  bwrap_args+=(--dir /etc/ssl/certs)
  certs_real="$(realpath -e -- /etc/ssl/certs 2>/dev/null)" || die "cannot resolve /etc/ssl/certs"
  bwrap_args+=(--ro-bind "$certs_real" /etc/ssl/certs)
fi

if [[ "$home_access_enabled" -eq 1 ]]; then
  # Expose the normal home tree for interactive development tools such as Zed,
  # then cover known credential stores and browser profiles with private mounts.
  bwrap_args+=(--bind "$home_real" /tmp/home)
  bwrap_args+=(
    --setenv XDG_CACHE_HOME /tmp/home/.cache
    --setenv XDG_CONFIG_HOME /tmp/home/.config
    --setenv XDG_DATA_HOME /tmp/home/.local/share
    --setenv XDG_STATE_HOME /tmp/home/.local/state
  )

  for relative_path in "${protected_home_relatives[@]}"; do
    protected_path="$home_real/$relative_path"
    [[ -e "$protected_path" || -L "$protected_path" ]] || continue

    protected_real="$(realpath -e -- "$protected_path" 2>/dev/null)" || continue
    case "$protected_real" in
      "$home_real"/*) ;;
      *) continue ;;
    esac

    sandbox_protected="/tmp/home/${protected_real#"$home_real"/}"
    if [[ -d "$protected_real" ]]; then
      bwrap_args+=(--tmpfs "$sandbox_protected")
    else
      bwrap_args+=(--dev-bind /dev/null "$sandbox_protected")
    fi
  done
fi

if [[ "$profile" == dev && "$cargo_cache_enabled" -eq 1 && -n "$home_real" ]]; then
  cargo_registry="$(realpath -e -- "$home_real/.cargo/registry" 2>/dev/null)" || {
    printf 'bwrap: --cargo-cache requested, but ~/.cargo/registry does not exist; continuing without it\n' >&2
  }
  if [[ -n ${cargo_registry:-} && -d "$cargo_registry" ]]; then
    bwrap_args+=(--bind "$cargo_registry" /tmp/cargo-home/registry)
  fi
fi

if [[ "$network_enabled" -eq 1 ]]; then
  for etc_file in nsswitch.conf hosts resolv.conf; do
    if [[ -e "/etc/$etc_file" ]]; then
      etc_real="$(realpath -e -- "/etc/$etc_file" 2>/dev/null)" || die "cannot resolve /etc/$etc_file"
      bwrap_args+=(--ro-bind "$etc_real" "/etc/$etc_file")
    fi
  done
fi

if [[ -n "$workspace" ]]; then
  if [[ "$profile" == dev ]]; then
    bwrap_args+=(--bind "$workspace" /workspace)
  else
    bwrap_args+=(--ro-bind "$workspace" /workspace)
  fi
  bwrap_args+=(--chdir /workspace --setenv PWD /workspace)
else
  bwrap_args+=(--chdir /tmp --setenv PWD /tmp)
fi

# Pass only conventional, non-secret compiler/build variables from a Nix
# development shell. Tokens, SSH agents, and arbitrary host environment are
# deliberately not inherited.
if [[ "$profile" == dev ]]; then
  for variable in \
    CC CXX CPP AR AS LD RANLIB STRIP OBJCOPY \
    CFLAGS CXXFLAGS CPPFLAGS LDFLAGS \
    PKG_CONFIG_PATH PKG_CONFIG_LIBDIR CMAKE_PREFIX_PATH CMAKE_GENERATOR \
    RUSTFLAGS CARGO_BUILD_TARGET GOFLAGS CGO_ENABLED \
    CGO_CFLAGS CGO_CPPFLAGS CGO_CXXFLAGS CGO_LDFLAGS GOPROXY; do
    value=${!variable-}
    if [[ -n "$value" ]]; then
      bwrap_args+=(--setenv "$variable" "$value")
    fi
  done
fi

for variable in TERM COLORTERM NO_COLOR; do
  value=${!variable-}
  if [[ -n "$value" ]]; then
    bwrap_args+=(--setenv "$variable" "$value")
  fi
done

exec "$BWRAP_BIN" "${bwrap_args[@]}" -- "$sandbox_command" "$@"
