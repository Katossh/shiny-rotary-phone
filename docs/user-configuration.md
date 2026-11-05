# User configuration

Starforge currently ships one supported machine profile: `workstation`.
It is intentionally not a generic multi-host installer or a collection of
selectable profiles.

The repository separates configuration by ownership:

- **Core system behavior:** reusable system-wide modules in `modules/nixos/`.
- **Host-specific behavior:** hardware, disk, boot, and machine facts in
  `hosts/workstation/`.
- **Personal preferences:** user-session settings in
  `home/katossh/preferences.nix`.
- **Terminal environment:** terminal packages, manifests, and dotfiles remain
  owned by the separate `terminal-dotfiles` repository.

Most users should change personal preferences in the single
`home/katossh/preferences.nix` file rather than editing the implementation
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

Edit only the values you want to change in `home/katossh/preferences.nix`.
For example, the relevant option definitions can be overridden in the
Home Manager user configuration as follows:

```nix
{
  starforge.user = {
    appearance = {
      themeMode = "auto";
      palette = "Tokyo-Night";
      fontFamily = "Inter";
    };

    desktop.niri = {
      keyboardLayout = "us,ru";
      keyboardLayoutOptions = "grp:alt_shift_toggle";
      gaps = 8;
    };
  };
}
```

The example is a configuration fragment; keep the existing module options
and imports in place.

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
