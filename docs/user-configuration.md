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
| `starforge.user.desktop.niri.gaps` | `12` | Niri layout gap in logical pixels; integer range 0–64. |
| `starforge.user.desktop.monitors` | `{}` | Niri output map keyed by connector name; supports mode, scale, and position. |

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
It also maintains one empty dynamic workspace at the end of each monitor, so
the initial layout contains five workspaces without pre-creating a fifth named
one. `Mod+1` through `Mod+4` focus the named workspaces; `Mod+5` targets the
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
| `1` | Web | Chromium, Firefox |
| `2` | Development | Zed, Kitty |
| `3` | Games | Steam and Steam games, osu!, Genshin / Anime Game Launcher |
| `4` | Communication | Discord, Telegram, LocalSend |

These are opening rules: they apply when a window is created, not retroactively
to windows that are already open. Move an existing window to one of the four
named workspaces with `Mod+Ctrl+1` through `Mod+Ctrl+4`; `Mod+Ctrl+5`
targets whichever workspace currently occupies position 5. Utilities and
media applications are no longer forced onto a separate named workspace and
open on the currently focused workspace by default. If an application is not
routed as expected, run `niri msg pick-window` and click it to inspect its
actual app ID; adjust the matching expression in `home/niri.nix` if the
application reports a different identifier.

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

-        default = 12;
+        default = 8;
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
- `modules/nixos/storage.nix` owns filesystem mount policy and the Btrfs scrub
  timer.
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

The workstation uses the `nix-cachyos-kernel` flake input, pinned to its
`release` branch in `flake.lock`. The host selects
`linuxPackages-cachyos-bore-lto-zen4` through
`inputs.nix-cachyos-kernel.overlays.pinned`, then extends the pinned
CachyOS kernel package set so its module packages are rebuilt against the
custom kernel without mixing in the root Nixpkgs package set.

The input deliberately does **not** follow the root Nixpkgs input. The pinned
overlay uses the exact Nixpkgs revision against which the CachyOS kernel and
its matching kernel-module package set were built. Replacing it with the
ordinary overlay or adding `nixpkgs.follows` can cause binary-cache misses
and package/patch mismatches.

### BORE + Clang ThinLTO + Zen 4

The selected variant combines:

- CachyOS's BORE scheduler patch.
- Clang/LLD with ThinLTO (`CONFIG_LTO_CLANG_THIN=y`).
- The explicit Zen 4 compiler target (`MZEN4`), rather than
  build-machine-specific `-march=native`.
- CachyOS's 1000 Hz timer, full-preemption, full-dynticks, and compiler
  optimisation configuration.
- BPF, BPF syscall, BTF metadata, and `SCHED_CLASS_EXT`, required by the
  workstation's sched_ext / SCX Loader setup.

The pinned CachyOS Nix builder disables `DEBUG_INFO_BTF` for LTO when its
`pahole` is older than 1.33. The current pinned builder uses pahole 1.32.
BTF is required by sched_ext, so this host explicitly restores
`DEBUG_INFO_BTF=y` and disables optional Rust kernel components
(`CONFIG_RUST=n`). Linux Kconfig does not support the Rust + BTF + LTO
combination in this kernel source. This preserves BTF for sched_ext at the
cost of Rust-based kernel components; it does not disable userspace Rust
applications or the Rust toolchain.

### Build the kernel locally

The kernel derivation sets `allowSubstitutes = false` and
`preferLocalBuild = true`. Nix therefore compiles the kernel from the
pinned CachyOS source and patches on this workstation instead of downloading
a prebuilt kernel from the third-party binary cache. Source archives,
toolchains, and ordinary build dependencies may still be downloaded or
substituted; only the kernel derivation itself is forced to build locally.

A full NixOS build will trigger this local kernel compilation:

```sh
nix build .#nixosConfigurations.workstation.config.system.build.toplevel --no-link
```

Expect a substantially longer build and significant CPU/RAM use. Do not
interrupt the build by deleting its store paths. The resulting generation is
not activated by this command.

### Binary cache and updates

The CachyOS kernel flake publishes signed binaries through
`https://cache.lantian.pub/lantian`. The repository configures that cache and
its public signing key in both the flake and the Nix daemon. This adds trust
in a third-party cache operator: Nix verifies downloaded substitutes against
the configured public key, but that does not make the cache operator part of
the NixOS project. The workstation's kernel derivation explicitly refuses
substitutes and is built locally; other outputs and dependencies may still
use configured caches.

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

### Removed local kernel overrides

The previous custom upstream kernel module and the Clang/LLD override have
been removed. Their manual Kconfig settings duplicated or conflicted with
settings already owned by the CachyOS package. The machine-specific
`X86_NATIVE_CPU` override is replaced by CachyOS's explicit Zen 4 target,
which is reproducible on CI and does not encode the build machine's exact CPU.

The final certificate-embedding image rebuild disables
`CONFIG_X86_DECODER_SELFTEST` as a **Make command-line override for that
repackaging derivation only**. Linux 7.3's `bzImage` target otherwise reruns
the x86 decoder host test, but Nixpkgs' pruned `kernel.dev` tree does not
retain `arch/x86/tools/insn_decoder_test.c`. The original CachyOS kernel
derivation has already built the kernel image; this avoids rerunning that
optional build-time test while embedding the module certificates. It does
not change the `.config` used to compile the kernel or its runtime
configuration.

The certificate-bundle integration in `modules/nixos/boot.nix`, Limine,
and Secure Boot configuration remain separate and unchanged. The kernel
command line retains the existing `mitigations=off` setting as explicitly
requested. This disables eligible CPU vulnerability mitigations and reduces
side-channel protection; it is a separate security trade-off from the
scheduler and memory tuning. Keep the previous boot generation until the new
kernel has booted and the desktop, networking, graphics, module loading, and
SCX scheduler have been checked.

After reboot, verify the actual kernel configuration and scheduler state:

```sh
uname -r
cat /proc/version
zgrep -E '^(CONFIG_(LTO_CLANG_THIN|MZEN4|SCHED_BORE|SCHED_CLASS_EXT|DEBUG_INFO_BTF)=|# CONFIG_RUST is not set)' /proc/config.gz
cat /sys/kernel/sched_ext/state
systemctl status scx.service
pgrep -af scx_lavd
```

`CONFIG_RUST` should be disabled by this host's LTO+BTF compatibility
override; `CONFIG_DEBUG_INFO_BTF` and `CONFIG_SCHED_CLASS_EXT` must be
enabled for sched_ext to attach to this kernel.

## Scheduling services

The workstation runs `scx_lavd` through the pinned NixOS `services.scx`
module. It starts the scheduler with `--performance`:

```nix
services.scx = {
  enable = true;
  scheduler = "scx_lavd";
  extraArgs = [ "--performance" ];
};
```

The selected CachyOS BORE/ThinLTO/Zen 4 kernel must expose sched_ext, BPF,
BPF syscall, and BTF; the kernel build retains `SCHED_CLASS_EXT` and BTF for
this purpose. The NixOS module requires Linux 6.12 or newer. Ananicy-cpp is
disabled so its per-process scheduling policy does not overlap with SCX.

After activating the new generation and rebooting, inspect the running state:

```sh
cat /sys/kernel/debug/sched/preempt
cat /sys/kernel/sched_ext/state
systemctl status scx.service
pgrep -af scx_lavd
```

The debugfs preemption file is available only when debugfs is mounted. The
selected kernel is configured for full preemption by default, so no explicit
`preempt=full` command-line parameter is required. sched_ext should report
`enabled` while LAVD is active.

## Kernel runtime tuning

The existing ZRAM configuration (`zstd`) and the current
`transparent_hugepage=always` mode are left unchanged. Only the THP
defragmentation policy is set to `defer+madvise` at boot.

The existing `boot.kernel.sysctl` set is extended with these values:

```nix
"vm.swappiness" = 150;
"vm.page-cluster" = 0;
"vm.dirty_background_bytes" = 67108864;
"vm.dirty_bytes" = 268435456;
"kernel.split_lock_mitigate" = 0;
```

The split-lock mitigation setting is separate from `mitigations=off`; both
are retained as explicitly requested. The NVMe udev rule sets the scheduler
to `none`, delegating request scheduling to the device. The `ntsync` module
is loaded for Wine/Proton, and its device node uses mode `0660` plus the
`uaccess` tag so logind can grant access to the active local seat rather
than making it world-writable.

No global architecture target, global stdenv change, or new `znver4`
userspace overlay is introduced. Existing package overlays remain unchanged.

## Apply changes safely

From the repository root:

```sh
sudo nixos-rebuild build --flake .#workstation
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
