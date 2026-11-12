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

## Workstation kernel build

The workstation uses a locally built kernel with a small set of explicit
Kconfig choices. The configuration is owned by
`modules/nixos/kernel.nix`; it extends the pinned Nixpkgs kernel rather than
replacing its general-purpose configuration.

| Kernel setting | Workstation value | Purpose |
|---|---|---|
| `HZ_1000` | Enabled | Selects the highest standard upstream timer frequency: 1000 Hz. Upstream Linux does not provide a 10,000 Hz Kconfig choice. |
| `NO_HZ_IDLE` | Enabled | Stops periodic scheduling ticks on idle CPUs. |
| `NO_HZ_FULL` | Disabled | Selects the mutually exclusive tickless-idle mode instead of full dynticks. Nixpkgs enables `NO_HZ_FULL` for 64-bit kernels by default, so this is explicitly overridden. |
| `SMP` | Enabled | Retains symmetric multiprocessing support. |
| `LTO_CLANG_THIN` | Requested when supported | Requests Clang ThinLTO when the active toolchain satisfies upstream Kconfig prerequisites; remains optional if Kconfig hides the option. |
| `X86_NATIVE_CPU` | Enabled for `workstation` | Uses `-march=native` when supported, targeting the CPU of the machine that compiles the kernel. |

The remaining kernel configuration and compiler optimization level are left
to Nixpkgs. In particular, this does not force `-O3`, change the preemption
model, or remove drivers and subsystems. The kernel uses Clang/LLD. ThinLTO
is requested on a best-effort basis: upstream Kconfig enables it only when
the active toolchain satisfies all prerequisites. When the option is hidden,
the kernel retains its default LTO choice rather than failing configuration.
Do not assume ThinLTO is active merely because it is requested here; verify
the final kernel `.config` before claiming it is enabled.

The kernel override also selects LLVM for host-side build tools. Nixpkgs
passes explicit `HOSTCC`, `HOSTCXX`, `HOSTAR`, and `HOSTLD` assignments in
its kernel make flags, so `LLVM=1` alone does not replace those values. The
workstation override supplies matching Clang and LLVM ar tools explicitly.
It also sets `HOSTLDFLAGS=--ld-path=...` to give Clang the exact LLD executable
and embeds an RPATH covering the Nix store library directories for `elfutils`
and OpenSSL. Linux host-side tools such as `objtool` and `certs/extract-cert`
link against `libelf.so.1` and `libcrypto.so.3`, respectively, and execute
during the kernel build. Without those runtime paths, their dynamic loaders
cannot find the shared libraries inside the sandbox. These flags address the
missing-GNU-`ld`, Clang's `invalid linker name '-fuse-ld=lld'`, and the missing
host-tool runtime-library failures.

The Nix daemon is configured with `nix.settings.cores = 12`, the per-derivation
parallelism limit. The Nixpkgs kernel derivation enables parallel builds, so
kernel compilation can use up to 12 jobs on this workstation. This is
separate from `max-jobs`, which controls how many independent derivations
Nix may build at the same time.

**Native CPU builds must run on the target workstation.** `X86_NATIVE_CPU`
targets the build machine, not the hardware described by the NixOS
configuration. Do not send the `workstation` kernel derivation to a remote
builder with a different CPU.

The flake also exposes `nixosConfigurations.workstation-ci`. This is a
portable CI-only variant with native CPU tuning disabled. GitHub Actions builds
that variant so CI cannot publish a kernel compiled for its runner to Cachix.
Install and rebuild the actual machine with `.#workstation`, not
`.#workstation-ci`.

Apply and test the kernel change using the normal NixOS generation workflow:

```sh
sudo nixos-rebuild build --flake .#workstation
sudo nixos-rebuild test --flake .#workstation
```

A successful build does not prove runtime behaviour. Reboot into the test
generation and verify the running kernel and timer configuration before
making it the default.

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
