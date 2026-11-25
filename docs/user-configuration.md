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

### Russia-direct split routing

The repository installs a v2rayN import file at
`~/.config/v2rayN/routing-ru.json`. It defines one routing profile with
these ordered rules:

1. Private IP ranges (`geoip:private`) go direct.
2. Private domains (`geosite:private`) go direct.
3. Russian domains (`geosite:category-ru`) go direct.
4. Russian destination IPs (`geoip:ru`) go direct.
5. Every remaining TCP/UDP connection goes through `proxy`.

The domain rule is intentional: a Russian domain hosted on a foreign CDN can
still use the direct connection. GeoIP rules are also used for non-Russian
domains whose resolved destination IP is in Russia. Set the Xray routing
profile's **Domain strategy** to `IPOnDemand` so Xray resolves domain names
when it needs an IP match.

Home Manager installs the `v2rayn-ru-routing` command. Run it from the
Wayland desktop session to copy the JSON to the clipboard:

```sh
v2rayn-ru-routing
```

In v2rayN:

1. Open **Settings → Routing Settings** and create a new routing profile,
   for example `Russia direct, rest proxy`.
2. Open that profile's rule editor and choose **Import Rules From Clipboard**.
3. Confirm **No / Replace**. This replaces the rules in the newly created
   profile with the five rules above; it does not change other profiles.
4. Set **Domain strategy** to `IPOnDemand`, save the profile, then select it
   as the active routing profile.

The helper only copies the file. It deliberately does not edit v2rayN's
SQLite-backed profile database or silently replace the currently active
profile. Re-run the command and repeat the import after intentionally changing
the declarative rules file.

These rules decide the outbound for traffic that reaches the v2rayN core.
For applications that honor the desktop proxy, use **System Proxy → Set
system proxy automatically**. To capture applications that ignore proxy
settings and other system traffic, enable **TUN** in v2rayN. The NixOS
networking module loads the kernel `tun` module for this purpose.

On Linux, v2rayN launches the core through `sudo` when TUN needs privileged
network changes. Keep the GUI running as the ordinary user and enter the
password when v2rayN asks; do not add passwordless sudo rules or grant
capabilities to the entire GUI. Check that the device exists with
`test -c /dev/net/tun`. Disconnect AmneziaVPN before enabling v2rayN TUN so
two VPN clients do not compete for the default route.

The routing profile does not independently configure DNS. DNS transport and
resolution policy are separate v2rayN settings; verify them separately if
you need DNS queries to use an encrypted resolver or a particular outbound.
Also remember that the profile does not force an application into the proxy:
without TUN, an application that ignores the system proxy can still connect
directly outside v2rayN.

After applying the configuration, restart v2rayN and verify the managed files:

```sh
xray version
test -x ~/.local/share/v2rayN/bin/xray/xray
ls -l ~/.local/share/v2rayN/bin/{geoip.dat,geosite.dat}
```

Installing the core does not create a system service, connect to a
server, enable TUN mode, or change the machine's default routing. The
networking module loads the kernel `tun` device, but TUN remains an explicit
runtime choice in v2rayN. On Linux, v2rayN starts the core through `sudo`
when it needs to create the tunnel and change routes; the GUI itself should
remain an ordinary user process.

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

Niri declares five persistent named workspaces: `"1"` through `"5"`.
Workspaces 1–3 are general-purpose: no application is pinned to them.
Workspace 4 is reserved for games, and workspace 5 is reserved for
communication apps. Niri also maintains an empty dynamic workspace at the end
of each monitor; on this single-monitor setup it initially occupies position
6. `Mod+1` through `Mod+5` focus the five named workspaces.
`Mod+Ctrl+1` through `Mod+Ctrl+5` move only the focused window to the
matching named workspace; other windows in its column stay behind.
`Mod+Ctrl+Page_Up` / `Mod+Ctrl+Page_Down` move the entire focused column
to the previous/next named workspace. No movement shortcut targets a workspace
outside the five named workspaces.

The five named workspaces remain present even when empty. Niri also keeps
its normal empty trailing workspace automatically; it is not one of the
five named workspaces and has no dedicated numeric shortcut.

#### Automatic application placement

Only games and communication apps have automatic workspace assignments:

| Workspace | Purpose | Applications |
| --- | --- | --- |
| `1` | General | No automatic application placement |
| `2` | General | No automatic application placement |
| `3` | General | No automatic application placement |
| `4` | Games | Steam and Steam games, osu!, Genshin / Anime Game Launcher |
| `5` | Communication | Discord, Telegram, LocalSend |
| Trailing | Dynamic | Niri-managed empty workspace; no shortcut targets it |

These are opening rules: they apply when a window is created, not retroactively
to windows that are already open. Move an existing window to the game or
communication workspace with `Mod+Ctrl+4` or `Mod+Ctrl+5`.
Browsers, terminals, editors, utilities, media applications, and any other app
without a matching rule open on the currently focused workspace by default;
none is pinned to workspaces 1–3. If an application is not routed as expected,
run `niri msg pick-window` and click it to inspect its actual app ID; adjust
the matching expression in `home/niri.nix` if the application reports a
different identifier.

Window navigation uses three modifier layers over the same home-row keys.
Horizontal focus is row-aware: rather than activating whichever tile Niri last
remembered in the neighboring column, it selects the tile with the nearest
vertical index to the currently focused window. In a 2×2 grid, pressing
`Mod+H` from the lower-right window therefore focuses the lower-left window.
Floating windows retain Niri's native directional focus behavior.

- **Focus — `Mod+H/J/K/L`:** `H/L` focus the vertically nearest
  window in the adjacent column, preserving the current tile row where
  possible; `K/J` focus the window above/below inside the current column.
  The `Mod+Left` / `Mod+Right` aliases use the same row-aware behavior.
- **Move — `Mod+Ctrl+H/J/K/L`:** `H/L` move the entire focused column
  left/right; `K/J` move the focused window up/down inside its column.
  `Mod+Ctrl+Up` / `Mod+Ctrl+Down` remain arrow-key aliases for vertical
  movement, and `Mod+Ctrl+Left` / `Mod+Ctrl+Right` remain aliases for
  moving columns.
- **Workspaces — `Mod+Alt+K/J`:** `K` focuses the previous workspace and
  `J` the next. `Mod+Alt+Up` / `Mod+Alt+Down`, `Mod+Up` /
  `Mod+Down`, and `Mod+Page_Up` / `Mod+Page_Down` remain alternatives.

The direct `Mod+1` through `Mod+5` bindings switch to a named workspace.
Move only the focused window to a specific named workspace with
`Mod+Ctrl+1` through `Mod+Ctrl+5`. Move the entire focused column to the
previous/next named workspace with `Mod+Ctrl+Page_Up` /
`Mod+Ctrl+Page_Down`; this movement is bounded to workspaces `1`–`5`
and does not enter Niri's automatically maintained trailing workspace.
Use `Mod+Ctrl+Comma` to consume a neighbouring window into the focused
column, or `Mod+Period` to expel a window from its column.

#### One-key layout presets

Use `Mod+Alt+1` through `Mod+Alt+7` to apply a complete layout to the tiled windows on the **currently focused workspace**:

| Shortcut | Preset | Column widths | Window arrangement |
|---|---|---|---|
| `Mod+Alt+1` | Main + tab stack | 65 / 35 | Focused main window + every other tiled window grouped as tabs on the right |
| `Mod+Alt+2` | Double | 50 / 50 | 2 side-by-side windows |
| `Mod+Alt+3` | Triple | 33.33 / 33.33 / 33.33 | 3 side-by-side windows |
| `Mod+Alt+4` | Quad | 25 / 25 / 25 / 25 | 4 side-by-side windows |
| `Mod+Alt+5` | Main + references | 20 / 60 / 20 | Reference / centered main / reference |
| `Mod+Alt+6` | 2×2 Grid | 50 / 50 | Two vertically stacked windows in each of two equal-width columns |
| `Mod+Alt+7` | Main + split sidebar | 65 / 35 | Focused main window left; two vertically stacked references right |

The percentages are proportions of the available layout width; Niri accounts for the configured gaps. Preset 1 needs at least two tiled windows: the currently focused window becomes the 65%-wide main column, while every other tiled window is consumed into a single 35%-wide tabbed column on the right. Switch between those tabs with the vertical focus bindings (`Mod+K` / `Mod+J`). Presets 2–4 need at least the number of windows shown; they start with the currently focused tiled window and select subsequent windows to the right, wrapping to the leftmost column when needed. Preset 5 places the focused window in the center, with its immediate left and right neighbors as references. Preset 6 needs four tiled windows and creates a 2×2 arrangement: two vertically stacked windows in each of two 50%-wide columns. Preset 7 needs three tiled windows: the focused window becomes a 65%-wide main column on the left, while the next two windows are stacked vertically in a 35%-wide sidebar on the right. Selection wraps around the workspace when necessary. For presets 2–4 and 6–7, tiled windows beyond the preset's selection remain in columns after the layout and are reachable by scrolling. Floating windows are ignored. Existing stacks are flattened before rebuilding the selected preset, and the originally focused window is refocused after the layout is applied. If there are too few tiled windows, the script reports the mismatch without changing the layout.

These shortcuts are one-shot transformations, not workspace profiles: they do not change the default width for future windows, and they do not affect other workspaces. The regular `Mod+R` width cycling and manual column/window resizing remain available.

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

The workstation uses the upstream prebuilt
`linuxPackages-cachyos-latest-zen4` package from the `release` branch of
`nix-cachyos-kernel`. The input is pinned in `flake.lock`, and the host uses
`inputs.nix-cachyos-kernel.overlays.pinned` to select the exact Nixpkgs
revision used for the published kernel binaries. Do not replace it with the
`default` overlay or override the kernel derivation if binary substitution
is desired.

This is the latest CachyOS kernel with the explicit Zen 4 compiler target
(`CONFIG_MZEN4=y`), without ThinLTO or the BORE scheduler patch. The pinned
release's CachyOS defconfig enables `CONFIG_DEBUG_INFO_BTF`, `CONFIG_BPF`,
`CONFIG_BPF_SYSCALL`, and `CONFIG_SCHED_CLASS_EXT`. No local
`structuredExtraConfig` override is needed: the unmodified package matches
the derivation published by the upstream release cache.

### BTF and sched_ext

BTF is required by `scx_lavd`. It is enabled in the upstream non-LTO Zen 4
kernel configuration together with BPF and `sched_ext`; the host does not
need to patch or rebuild the kernel to restore it. The NixOS
`services.scx-loader` module starts `scx_lavd` in Auto mode with the
`--performance` argument. Ananicy-cpp is disabled to avoid overlapping
scheduling policy. The loader exposes `scxctl` for runtime inspection and
scheduler management.

After activation and reboot, verify the kernel and scheduler state:

```sh
uname -r
zgrep -E '^(CONFIG_(LTO_NONE|MZEN4|BPF|BPF_SYSCALL|SCHED_CLASS_EXT|DEBUG_INFO_BTF)=|# CONFIG_(LTO_CLANG_THIN|SCHED_BORE) is not set)' /proc/config.gz
test -r /sys/kernel/btf/vmlinux
cat /sys/kernel/sched_ext/state
systemctl status scx_loader.service
scxctl get
pgrep -af scx_lavd
```

Expected results: `CONFIG_LTO_NONE=y`, `CONFIG_MZEN4=y`,
`CONFIG_BPF=y`, `CONFIG_BPF_SYSCALL=y`,
`CONFIG_SCHED_CLASS_EXT=y`, and `CONFIG_DEBUG_INFO_BTF=y`;
ThinLTO and BORE are not enabled. `/sys/kernel/btf/vmlinux` is readable,
sched_ext is enabled, and `scx_lavd` is running.

The final certificate-embedding image rebuild is a separate repackaging step:
it disables `CONFIG_X86_DECODER_SELFTEST` only for that image build and does
not change the kernel configuration.

### Binary cache and updates

The upstream `release` branch contains kernels already built by its Hydra CI
and published to the project's Attic binary cache. The root flake and the
installed Nix daemon configure `https://cache.lantian.pub/lantian` with its
public signing key. Keep the `release` input pinned and retain the
`pinned` overlay; using a different Nixpkgs revision or customizing the
kernel changes the derivation and can force a local kernel build.

If the cache is unreachable, Nix may be unable to download the substitute;
`--fallback` allows it to continue by building from source, which is much
more expensive than downloading the prebuilt kernel.

Update only this input when reviewing a new CachyOS kernel:

```sh
nix flake update nix-cachyos-kernel
git diff -- flake.lock
nix flake check path:. --no-build --no-update-lock-file --show-trace
nix build path:.#nixosConfigurations.workstation.config.system.build.toplevel --no-link
```

### AutoFDO and Propeller are not enabled

The selected kernel is non-LTO; AutoFDO and Propeller are not enabled. The
CachyOS builder exposes AutoFDO separately and requires an LTO build and a
compatible profile. Do not describe this kernel as profile-guided.

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
