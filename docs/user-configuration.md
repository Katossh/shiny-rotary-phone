# User configuration

Starforge currently ships one supported machine profile: `workstation`.
It is intentionally not a generic multi-host installer or a collection of
selectable profiles.

## Workstation account identity

The workstation login name is configured once in
`hosts/workstation/default.nix`:

```nix
starforge.user.username = "katossh";
```

The option accepts a 1–32 character login name beginning with a lowercase
letter or underscore and containing only lowercase letters, digits,
underscores, and hyphens. The name `root` is reserved and rejected.

This value controls the NixOS normal-user account, the Home Manager user entry,
the `/home/<username>` directory, and the libvirt socket/Polkit authorization.
The Home Manager modules themselves live in the neutral `home/` directory.
For a fresh installation, `install.sh --install` evaluates this option and
prompts you to set the password for that account.

**Changing the name on an already installed system is not an account migration.**
NixOS does not automatically rename the existing account, move its home
directory, transfer its password, or change ownership of existing files.
Keep the current value (`katossh`) on the existing workstation unless you
have separately planned and verified a user-account migration. Set a different
name before a fresh installation instead.

The repository separates configuration by ownership:

- **Core system behavior:** reusable system-wide modules in `modules/nixos/`.
- **Host-specific behavior:** hardware, disk, boot, and machine facts in
  `hosts/workstation/`.
- **Personal preferences:** user-session settings in
  `home/preferences.nix`.
- **Terminal environment:** terminal packages, manifests, and dotfiles remain
  owned by the separate `terminal-dotfiles` repository.

Most users should change personal preferences in the single
`home/preferences.nix` file rather than editing the implementation
modules that consume them.

### Network-dependent runtime behavior

Two managed integration points can download data outside the Nix store:

- Home Manager activation invokes the `terminal-dotfiles` installer, which
  restores Oh My Zsh and its plugins from their upstream Git repositories.
  Activation may therefore need network access when that data is missing or
  being repaired. The terminal package set itself remains declarative.
- The `dsh` launcher runs `npx --yes @deepseek-ai/dsh`, which fetches an
  unpinned npm package on first use and caches it under the user's npm cache.
  It is not part of the Nix store closure.

Both downloads are intentional upstream integration points, not NixOS package
management. Review or pin them separately if you require a fully offline or
byte-reproducible user environment.

## Network proxy client

The workstation user receives the **v2rayN** desktop client through
Home Manager (`pkgs.v2rayn` from the root flake's locked Nixpkgs input).
v2rayN is an open-source GUI frontend that supports Xray and sing-box cores.
The Nixpkgs package installs the GUI frontend; it does not bundle the Xray
core binaries. Home Manager therefore installs `pkgs.xray` separately and
links it into the exact per-user location that v2rayN checks on Linux:
`~/.local/share/v2rayN/bin/xray/xray`. It also links the matching
`geoip.dat` and `geosite.dat` from the locked `v2ray-rules-dat` package
into `~/.local/share/v2rayN/bin/`, which v2rayN passes to Xray as its asset
directory.

The Xray executable is also available as `xray` in the user's shell. The
core is pinned independently to upstream Xray-core v26.11.9 by
`pkgs/xray/default.nix`; fixed source and Go vendor hashes make the source
reproducible without updating the root Nixpkgs lock. The workstation overlay
in `modules/nixos/xray.nix` installs this package for Home Manager.
The `geoip.dat` and `geosite.dat` files remain supplied by the root
Nixpkgs-locked `v2ray-rules-dat` package. Do not install or update this
managed core through v2rayN's core downloader: update the pinned version and
hashes in the package expression, then rebuild the configuration instead.
Select the Xray core in v2rayN for VLESS + REALITY profiles.

After applying the configuration, restart v2rayN and verify the managed files:

```sh
xray version
test -x ~/.local/share/v2rayN/bin/xray/xray
ls -l ~/.local/share/v2rayN/bin/{geoip.dat,geosite.dat}
```

Installing the core does not create a system service or enable TUN mode.

Installing the client does not connect to a server, enable TUN mode, install
a system-wide VPN service, or change the machine's default routing. Do not
run the desktop application as root. TUN mode requires separate privileged
network setup and should be reviewed independently before use.

There is currently no dedicated AppArmor policy for v2rayN in
`modules/nixos/apparmor.nix`; this installation must not be treated as an
AppArmor-confined workload. Review its runtime file and network access before
considering a dedicated profile.

## Supported preferences

The following typed options are declared under `starforge.user` in the
Home Manager configuration.

| Option | Default | Accepted values / effect |
|---|---|---|
| `starforge.user.appearance.themeMode` | `"dark"` | `"dark"`, `"light"`, or `"auto"`; controls Noctalia's theme mode. |
| `starforge.user.appearance.paletteSource` | `"community"` | `"builtin"`, `"community"`, or `"wallpaper"`; selects the palette source. |
| `starforge.user.appearance.palette` | `"Catppuccin"` | Built-in palette used when `paletteSource = "builtin"`. |
| `starforge.user.appearance.communityPalette` | `"Catppuccin Frappe Peach"` | Community palette name used when `paletteSource = "community"`. |
| `starforge.user.appearance.fontFamily` | `"Inter"` | Fontconfig family name used for Noctalia's UI and bar; the font must already be installed. |
| `starforge.user.hardware.deepcoolDigital.enable` | `false` | Starts the DeepCool Digital daemon as a per-user systemd service; requires a compatible display and a host-specific hidraw udev ACL. |
| `starforge.user.desktop.niri.keyboardLayout` | `"us,ru"` | Comma-separated XKB layout identifiers passed to Niri. |
| `starforge.user.desktop.niri.keyboardLayoutOptions` | `"grp:alt_shift_toggle"` | XKB layout options passed to Niri. |
| `starforge.user.desktop.niri.gaps` | `8` | Niri layout gap in logical pixels; integer range 0–64. |
| `starforge.user.desktop.monitors` | `{}` | Niri output map keyed by connector name; supports mode, scale, and position. |

Niri uses this gap for both the spacing between windows and the outer margins on all four sides. The default therefore gives 8 logical pixels for each of those spacing dimensions.

Built-in Noctalia palettes supported by the currently pinned Noctalia input:

- `Ayu`
- `Catppuccin`
- `Dracula`
- `Eldritch`
- `Gruvbox`
- `Kanagawa`
- `Noctalia`
- `Nord`
- `Rosé Pine`
- `Tokyo-Night`

The `palette` option selects a Noctalia built-in palette when
`paletteSource = "builtin"`. `communityPalette` selects the community palette
when the source is `"community"`; the current default is Catppuccin Frappe
Peach. The wallpaper source derives its palette from the active wallpaper.

These choices do not change the terminal-dotfiles theme or install fonts.
Noctalia's theme mode can synchronize the desktop color-scheme preference
according to Noctalia's own `sync_color_scheme` setting.

## Noctalia configuration and portable assets

The curated Noctalia configuration is stored in
`home/noctalia/settings.toml` and loaded by the existing
`home/noctalia.nix` Home Manager module. Typed appearance preferences from
`home/preferences.nix` override the corresponding font and palette values.
Do not edit generated files under `~/.config/noctalia/`.

Wallpaper paths are resolved from the Home Manager Pictures directory:
`<XDG Pictures>/Wallpapers` (normally `~/Pictures/Wallpapers`). The
configuration retains the six wallpaper filenames from the export, but the
image files are not committed to this repository. Copy those files to the same
directory on another installation; the Wallhaven plugin downloads there too.

Lock-screen widgets no longer pin themselves to the workstation's `DP-1`
connector. They retain the original 3440×1440 placement canvas, allowing
Noctalia to scale their coordinates for a different output. Adjust the widgets
in Noctalia Settings if a new display layout needs a different composition.

The exported city address is not stored in this public repository.
`location.auto_locate = true` lets Noctalia resolve approximate coordinates
from the current public IP through its location service. This avoids a
machine-specific city value, but means Noctalia's location service receives
the approximate network-derived location. The Weather service is enabled
because the exported bar layout includes its widget. See the
[Noctalia location documentation](https://docs.noctalia.dev/noctalia/services/location/).

Noctalia's native Polkit agent is enabled in the shell configuration. The
separate Home Manager `polkit-gnome` agent is therefore not started; do not
enable a second session agent alongside Noctalia. This does not disable the
system Polkit service or its authorization rules. See
[Noctalia's shell configuration](https://docs.noctalia.dev/noctalia/configuration/shell/).

The export contains no `[theme.templates]` selection and no custom palette
files. No template IDs have been guessed or enabled. Built-in and community
templates are opt-in; inspect available IDs with
`noctalia theme --list-templates` and add the chosen IDs to the declarative
configuration when ready. See
[Noctalia App Theming](https://docs.noctalia.dev/noctalia/theming/app-theming/).
The originally uploaded archive was only a symlink into `/nix/store`, so it
did not provide any additional template or palette files to migrate.

### Niri workspaces

Niri declares four persistent named workspaces: `"1"` through `"4"`.
Workspaces 1–3 have automatic application assignments; workspace 4 is a
persistent reserve. Niri also maintains one empty dynamic workspace at the end
of each monitor, which occupies position 5 in a fresh single-monitor session.
`Mod+1` through `Mod+4` focus the named workspaces; `Mod+5` targets the
workspace currently in position 5. `Mod+Ctrl+1` through `Mod+Ctrl+4` move
the focused column to the named workspaces, while `Mod+Ctrl+5` targets the
workspace currently in position 5.

The fifth workspace is dynamic, not persistent. Niri always keeps an empty
workspace at the end; when a window is placed there, it creates another empty
workspace below it. The count therefore starts at five but is not a hard
maximum.

#### Automatic application placement

New windows are routed to these workspaces by their Niri application ID:

| Workspace | Purpose | Applications |
| --- | --- | --- |
| `1` | Development | Zed, Alacritty |
| `2` | Games | Steam and Steam games, osu!, Genshin / Anime Game Launcher |
| `3` | Communication | Discord, Telegram, LocalSend |
| `4` | Reserve | No automatic application placement |
| `5` | Reserve | Niri's empty dynamic workspace |

These are opening rules: they apply when a window is created, not retroactively
to windows that are already open. Move an existing window to one of the four
named workspaces with `Mod+Ctrl+1` through `Mod+Ctrl+4`; `Mod+Ctrl+5`
targets whichever workspace currently occupies position 5. Browsers,
utilities, media applications, and any other app without a matching rule open
on the currently focused workspace by default; browsers are not pinned to a
dedicated workspace. If an application is not routed as expected, run
`niri msg pick-window` and click it to inspect its actual app ID; adjust the
matching expression in `home/niri.nix` if the application reports a different
identifier.

Navigate vertically between workspaces with either `Mod+Up` / `Mod+Down`
or the Vim-style `Mod+K` / `Mod+J` shortcuts. `Mod+Page_Up` and
`Mod+Page_Down` remain available as alternatives. Vertical window focus is
available on `Mod+Alt+Up` / `Mod+Alt+Down` and `Mod+Alt+K` / `Mod+Alt+J`.

Reorder windows inside a column with `Mod+Ctrl+Up` / `Mod+Ctrl+Down` or
the Vim-style `Mod+Ctrl+K` / `Mod+Ctrl+J`. These shortcuts bypass application
shortcut inhibition. They only visibly reorder windows when the column contains
multiple windows; Niri otherwise lays windows out as separate horizontal
columns. Use `Mod+Ctrl+Comma` to consume a neighbouring window into the
focused column, or `Mod+Period` to expel a window from its column. Dynamic
workspaces continue to work beyond the initial five.

## Example

To use automatic light/dark switching, change the corresponding defaults in
`home/preferences.nix`:

```diff
-        default = "dark";
+        default = "auto";

-        default = "Catppuccin";
+        default = "Tokyo-Night";

```

Keep each option's declared type and description intact. The enum types reject
unsupported theme modes and palette names; the gap type rejects values outside
the 0–64 range.

## Display and hardware customization

The Home Manager option `starforge.user.desktop.monitors` is declared in
`home/preferences.nix`. It is keyed by exact connector names reported by
Niri. Its default is empty, so a host without an explicit display map uses
Niri's preferred-mode behavior.

The current workstation's physical display choice is kept in
`hosts/workstation/displays.nix`:

```nix
{ config, ... }:

{
  home-manager.users.${config.starforge.user.username}.starforge.user.desktop.monitors = {
    "DP-1" = {
      mode = "3440x1440";
    };
  };
}
```

Discover connector names and advertised modes in a running Wayland session:

```sh
niri msg outputs
```

For a multi-monitor layout, add one attribute per output. Replace
`HDMI-A-1` below with an actual connector reported by Niri:

```nix
{
  "DP-1" = {
    mode = "3440x1440";
  };
  "HDMI-A-1" = {
    mode = "1920x1080@60.000";
    scale = 1.0;
    position = { x = 3440; y = 0; };
  };
}
```

- `mode` is optional; omitting it leaves mode selection to Niri.
- `scale` is optional and must be greater than 0 and no greater than 10.
- `position` is an optional logical `x`/`y` position. Omitting it lets
  Niri position the output automatically.

The Home Manager Niri module validates the generated KDL during the system
build. This validates syntax, not whether a physical connector or mode exists
on hardware that is not attached during the build.

### Hardware ownership

- `hosts/workstation/hardware.nix` contains this host's AMD CPU/GPU modules,
  early AMDGPU setup, and exact hidraw permissions for the AK620 Digital,
  VXE receiver, and LEKU keyboard.
- `modules/nixos/hardware.nix` contains common capabilities such as firmware,
  graphics, Bluetooth, fwupd, SMART monitoring, and common diagnostic tools.
- `modules/nixos/storage.nix` owns root filesystem options and the Btrfs scrub
  timer. The machine-local hardware configuration owns the separate
  subvolume mount options for `/home`, `/nix`, and `/var/log`.
- `hosts/workstation/hardware-configuration.nix` remains generated storage,
  boot, and detected-device configuration; do not hand-edit it for routine
  personalization.

When adapting Starforge to another computer, replace the host-specific
hardware modules and device rules with ones appropriate to the actual CPU/GPU
and peripherals. Regenerate `hardware-configuration.nix` for the target
machine and review it rather than copying this workstation's disk and device
details.

### DeepCool AK620 Digital display

The upstream [`deepcool-digital-linux` project](https://github.com/Nortank12/deepcool-digital-linux)
supports both AK620 Digital and AK620 Digital SE; these variants share the same USB product ID. The package is available from
the repository's pinned Nixpkgs input. The Home Manager module in
`home/deepcool-digital.nix` installs the CLI and runs the display daemon as a
systemd **user** service.

The typed option `starforge.user.hardware.deepcoolDigital.enable` defaults
to `false`. The workstation opts in from `hosts/workstation/hardware.nix`
because that machine has an AK620 Digital. Other machine profiles should leave
the option disabled unless they have a supported display and provide their
own matching device permissions.

The workstation grants access to the following HID interfaces without
running the applications as root:

- ATK Hub: USB vendor ID `373b` (all product IDs exposed by the ATK receiver
  family).
- VXE NordicMouse 1K receiver: USB ID `3554:f58a`.
- LEKU NUT65 keyboard for VIA: USB ID `342d:e51a`.
- DeepCool AK620 Digital / Digital SE: USB ID `3633:0002`.

Each matching `/dev/hidraw*` node is assigned to the configured workstation
account with `OWNER` and `MODE="0600"`. This lets that account's Chromium
session open the devices through WebHID while keeping access unavailable to
other local users. It deliberately avoids `MODE="0666"` and does not grant
access to unrelated HID devices. Unlike `uaccess`, this ownership is not
revoked when the user's session becomes inactive; that is intentional for
this single-user workstation. No Intel RAPL permission is needed on this AMD
workstation.

These rules are provided through `services.udev.packages` as
`70-workstation-hidraw.rules`. Only the listed vendor/product matches are
affected. When the rules change, already-connected devices may retain their
old node ownership until udev processes a fresh event. After applying the
configuration, run:

```sh
sudo udevadm control --reload-rules
sudo udevadm trigger --action=add --subsystem-match=hidraw
sudo udevadm settle
```

Alternatively, unplug and reconnect the keyboard and mouse receiver. Verify
the relevant node's USB IDs and ownership with:

```sh
udevadm info --attribute-walk --name=/dev/hidrawN
stat -c '%A %U:%G %n' /dev/hidrawN
```

Replace `/dev/hidrawN` with the node whose parent attributes show the target
VID/PID. It should be owned by the configured user and have permissions
`crw-------`. After that, reload VIA or `hub.atk.pro` in Chromium. If ATK
Hub still reports the mouse asleep, verify that the mouse itself is awake and
the receiver is connected; the permission rule cannot wake a powered-off or
disconnected mouse.
Check the user service and its logs with:

```sh
systemctl --user status deepcool-digital-linux.service
journalctl --user -u deepcool-digital-linux.service -b
```

## RAM-backed temporary storage

The workstation mounts the entire `/tmp` directory as tmpfs using the native
NixOS options in `modules/nixos/memory.nix`:

```nix
boot.tmp = {
  useTmpfs = true;
  tmpfsSize = "8G";
};
```

`8G` is the maximum size of the tmpfs, **not** 8 GiB of RAM reserved at
boot. Physical memory is consumed as files are written. Tmpfs pages can be
swapped out under memory pressure; this workstation has zram swap enabled.
The contents are temporary and are lost when the filesystem is unmounted,
including during a reboot.

Every application that uses the normal `/tmp` path automatically uses this
tmpfs; no per-command `TMPDIR` override is needed. This avoids storing those
temporary files on the root filesystem, but it does not guarantee a large
performance improvement: disk-backed filesystems also benefit from the Linux
page cache.

**There is no automatic fallback to disk.** If concurrent applications fill
the 8 GiB limit, further writes fail with `ENOSPC`. In particular, large
builds can fail when their temporary data exceeds the available tmpfs space.
For a workload that needs more temporary space, use a separate disk-backed
directory and set `TMPDIR` for that command rather than increasing the tmpfs
limit without checking memory pressure.

After building and testing a new NixOS generation, verify the mount and its
current usage with:

```sh
findmnt -T /tmp -o TARGET,SOURCE,FSTYPE,OPTIONS
df -h /tmp
```

Build and test the configuration using:

```sh
sudo nixos-rebuild build --flake .#workstation
sudo nixos-rebuild test --flake .#workstation
```

## CachyOS kernel

The workstation uses the `nix-cachyos-kernel` flake input, pinned in
`flake.lock`. The host selects `linuxPackages-cachyos-latest-lto-zen4` and
extends it in `hosts/workstation/hardware.nix`:

- Clang/LLD ThinLTO and the explicit Zen 4 compiler target.
- No BORE scheduler patch.
- `CONFIG_DEBUG_INFO_BTF=y` and in-kernel Rust disabled. Upstream Kconfig
  does not permit `CONFIG_RUST` together with BTF and LTO; the NixOS Rust
  toolchain and Rust applications are unaffected.

The input deliberately does **not** follow the root Nixpkgs input. The pinned
overlay uses the exact Nixpkgs revision against which the CachyOS kernel and
its matching kernel-module set were built; replacing it or adding
`nixpkgs.follows` can cause cache misses and patch mismatches.

Because this is a custom kernel configuration, the upstream prebuilt CachyOS
cache may not contain the resulting kernel derivation. A build can therefore
compile the kernel locally; allow enough disk space and build time, and keep a
known-good generation until the new kernel has booted. The final
certificate-embedding image rebuild is a separate repackaging step: it
disables `CONFIG_X86_DECODER_SELFTEST` only for that image build and does not
change the kernel `.config`.

### BTF and sched_ext

BTF is required by `scx_lavd`, and the host enables it explicitly. The NixOS
`services.scx` module starts `scx_lavd --performance`; Ananicy-cpp is disabled
to avoid overlapping scheduling policy.

After activation and reboot, verify the kernel and scheduler state:

```sh
uname -r
zgrep -E '^(CONFIG_(LTO_CLANG_THIN|MZEN4|SCHED_CLASS_EXT|DEBUG_INFO_BTF)=|# CONFIG_(SCHED_BORE|RUST) is not set)' /proc/config.gz
test -r /sys/kernel/btf/vmlinux
cat /sys/kernel/sched_ext/state
systemctl status scx.service
pgrep -af scx_lavd
```

Expected results: `CONFIG_LTO_CLANG_THIN=y`, `CONFIG_MZEN4=y`,
`CONFIG_SCHED_CLASS_EXT=y`, and `CONFIG_DEBUG_INFO_BTF=y`; BORE and in-kernel
Rust are not enabled. `/sys/kernel/btf/vmlinux` is readable, sched_ext is
enabled, and `scx_lavd` is running.

### Binary cache and updates

The CachyOS kernel flake publishes signed binaries through
`https://cache.lantian.pub/lantian`. The repository configures that cache and
its public signing key in both the flake and the Nix daemon. Nix verifies
downloaded substitutes against the configured public key, but this does not
make the third-party cache operator part of the NixOS project.

Update only this input when reviewing a new CachyOS kernel:

```sh
nix flake update nix-cachyos-kernel
git diff -- flake.lock
nix flake check path:. --no-build --no-update-lock-file --show-trace
nix build path:.#nixosConfigurations.workstation.config.system.build.toplevel --no-link
```

### AutoFDO and Propeller are not enabled

ThinLTO is enabled, but this package selection does not enable AutoFDO or
Propeller. The CachyOS Nix builder exposes AutoFDO separately and defaults it
to disabled; enabling it requires a compatible profile. Do not describe this
build as profile-guided unless a profile has actually been supplied and used.

### CPU mitigations

The configured kernel command line uses `mitigations=auto,nosmt`, enabling the
kernel's available CPU-vulnerability mitigations and full cross-thread
protection. SMT is disabled only if the detected CPU requires it for a
complete mitigation; affected processors may therefore expose fewer logical
CPUs and lower parallel throughput. Verify the active command line with
`cat /proc/cmdline` and keep the previous boot generation until the new kernel
has booted.

## Kernel runtime tuning

The existing ZRAM configuration (`zstd`) is retained. The repository does not
set the THP enabled mode; the current host reports `always`. Only the THP
defragmentation policy is set to `defer+madvise` at boot.

The existing `boot.kernel.sysctl` set is extended with these values:

```nix
"vm.swappiness" = 150;
"vm.page-cluster" = 0;
"vm.dirty_background_bytes" = 67108864;
"vm.dirty_bytes" = 268435456;
"kernel.split_lock_mitigate" = 1;
```

The split-lock mitigation is explicitly enabled with
`kernel.split_lock_mitigate=1`; this is independent of the CPU vulnerability
mitigations selected by `mitigations=auto,nosmt`. The NVMe udev rule sets the
scheduler to `none`, delegating request scheduling to the device. The `ntsync` module
is loaded for Wine/Proton, and its device node uses mode `0660` plus the
`uaccess` tag so logind can grant access to the active local seat rather
than making it world-writable.

No global architecture target, global stdenv change, or new `znver4`
userspace overlay is introduced. Existing package overlays remain unchanged.

## Apply changes safely

From the repository root, first evaluate and build the system without
activating it:

```sh
sudo nixos-rebuild dry-build --flake .#workstation
```

For a full local build whose result is available in the Nix store:

```sh
sudo nixos-rebuild build --flake .#workstation
```

To boot the configuration for testing without making it the default
generation:

```sh
sudo nixos-rebuild test --flake .#workstation
```

Test the desktop session, keyboard switching, Noctalia palette, and font
rendering before making the generation the default:

```sh
sudo nixos-rebuild switch --flake .#workstation
```

A Home Manager/Noctalia configuration change is declarative. Do not edit
generated files under `~/.config/noctalia/` or Niri's generated runtime
configuration to make a permanent change.

### Noctalia GUI overrides

Noctalia loads GUI-managed settings from its state directory after the
hand-written configuration. A value saved by Noctalia Settings can therefore
override the value generated from Nix. If a declarative value appears not to
take effect, inspect:

```text
~/.local/state/noctalia/settings.toml
```

Use Noctalia Settings to reset or change the conflicting GUI-managed value.
Do not edit the generated Home Manager config file as a workaround.

The exported GUI configuration contained a 5-second passwordless lock-screen
grace period. The declarative configuration deliberately keeps this at
0 seconds, preserving the repository's existing security policy. Reset that
GUI-managed lock-screen value (or remove only its
`lockscreen.grace_period_seconds` override from the state file after making a
backup); otherwise the app-managed state value wins over Home Manager. Do not
delete the entire state file blindly if it contains other app-managed settings.

### Scope and security

The typed preference surface deliberately avoids general system
policy, boot settings, encryption, or broad privileged-service controls.
Noctalia's session and lock-screen behavior remains user-scoped in its Home
Manager configuration; system-wide Polkit policy and hardware access remain
owned by NixOS modules and the corresponding host profile. The DeepCool
option is a narrow exception for a user-scoped daemon; its device ACL remains
host-owned and restricted to the exact cooler HID ID.

Do not introduce a generic profile selector or multi-host abstraction until
there is a concrete second supported host and a tested reason to share the
configuration across different hardware.
