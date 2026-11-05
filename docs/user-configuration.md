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
| `starforge.user.appearance.palette` | `"Catppuccin"` | One of the built-in Noctalia palettes listed below. |
| `starforge.user.appearance.fontFamily` | `"Inter"` | Fontconfig family name used for Noctalia's UI; the font must already be installed. |
| `starforge.user.desktop.niri.keyboardLayout` | `"us,ru"` | Comma-separated XKB layout identifiers passed to Niri. |
| `starforge.user.desktop.niri.keyboardLayoutOptions` | `"grp:alt_shift_toggle"` | XKB layout options passed to Niri. |
| `starforge.user.desktop.niri.gaps` | `12` | Niri layout gap in logical pixels; integer range 0–64. |

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

The palette option selects a Noctalia built-in palette. It does not change the
terminal-dotfiles theme, install fonts, or guarantee that every third-party
application supports automatic color-scheme switching. Noctalia's theme mode
can synchronize the desktop color-scheme preference according to Noctalia's
own `sync_color_scheme` setting.

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

### Scope and security

This preference surface deliberately excludes hardware facts, boot settings,
encryption, service enablement, security policy, lock-screen timeouts, and
privileged features. Those remain owned by the host/system modules and should
not become personal toggles merely for convenience.

Do not introduce a generic profile selector or multi-host abstraction until
there is a concrete second supported host and a tested reason to share the
configuration across different hardware.
