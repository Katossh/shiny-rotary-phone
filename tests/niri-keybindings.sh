#!/usr/bin/env bash
set -Eeuo pipefail

config=${1:?usage: test-niri-keybindings.sh PATH_TO_NIRI_CONFIG}

assert_contains() {
  local expected=$1
  if ! grep -Fq -- "$expected" "$config"; then
    printf 'Missing Niri binding: %s\n' "$expected" >&2
    exit 1
  fi
}

assert_absent() {
  local unexpected=$1
  if grep -Fq -- "$unexpected" "$config"; then
    printf 'Unexpected Niri binding remains: %s\n' "$unexpected" >&2
    exit 1
  fi
}

# Mod is the focus layer.
assert_contains '"Mod+H"."focus-column-left" = { };'
assert_contains '"Mod+L"."focus-column-right" = { };'
assert_contains '"Mod+K"."focus-window-up" = { };'
assert_contains '"Mod+J"."focus-window-down" = { };'

# Ctrl+Mod is the movement layer.
assert_contains '"Mod+Ctrl+H"."move-column-left" = { };'
assert_contains '"Mod+Ctrl+L"."move-column-right" = { };'
grep -A5 -F '"Mod+Ctrl+K" = {' "$config" | grep -Fq '"move-window-up" = { };'
grep -A5 -F '"Mod+Ctrl+J" = {' "$config" | grep -Fq '"move-window-down" = { };'

# Alt+Mod is the workspace-navigation layer.
assert_contains '"Mod+Alt+K"."focus-workspace-up" = { };'
assert_contains '"Mod+Alt+J"."focus-workspace-down" = { };'

# Guard against the previous accidental overlap between layers.
assert_absent '"Mod+J"."focus-workspace-down" = { };'
assert_absent '"Mod+K"."focus-workspace-up" = { };'
assert_absent '"Mod+Alt+K"."focus-window-up" = { };'
assert_absent '"Mod+Alt+J"."focus-window-down" = { };'

# Direct workspace switching and focused-window transfers remain available.
for workspace in 1 2 3 4 5; do
  assert_contains "\"Mod+$workspace\""
  assert_contains "\"Mod+Ctrl+$workspace\""
done

printf 'Niri home-row keyboard-layer tests passed.\n'
