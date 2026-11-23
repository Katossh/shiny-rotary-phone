#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  printf 'Usage: niri-focus-adjacent-window {left|right}\n' >&2
}

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name='Niri window focus' "$1" "$2" >/dev/null 2>&1 || true
  fi
}

if (($# != 1)); then
  usage
  exit 2
fi

direction=$1
case "$direction" in
  left|right) ;;
  *)
    usage
    exit 2
    ;;
esac

command -v niri >/dev/null 2>&1 || {
  printf 'niri-focus-adjacent-window: niri was not found in PATH.\n' >&2
  exit 1
}

windows_response=$(niri msg --json windows) || {
  notify 'Window focus failed' 'Could not query the Niri window list.'
  exit 1
}

focus_result=$(jq -ce --arg direction "$direction" '
  if type != "array" then
    error("Niri did not return a window array")
  else
    . as $windows
    | ($windows | map(select(.is_focused == true)) | .[0]) as $current
    | if $current == null then
        { kind: "none" }
      elif $current.is_floating == true then
        # Preserve Niri native directional focus for floating windows.
        { kind: "floating" }
      elif (($current.workspace_id | type) != "number") then
        error("focused tiled window has no workspace ID")
      elif (($current.layout.pos_in_scrolling_layout | type) != "array")
        or (($current.layout.pos_in_scrolling_layout | length) != 2) then
        error("focused tiled window has no column/tile indices")
      else
        ($current.layout.pos_in_scrolling_layout[0]) as $current_column
        | ($current.layout.pos_in_scrolling_layout[1]) as $current_row
        | (if $direction == "left" then $current_column - 1 else $current_column + 1 end) as $target_column
        | [
            $windows[]
            | select(
                .is_floating == false
                and .workspace_id == $current.workspace_id
                and (.layout.pos_in_scrolling_layout | type) == "array"
                and (.layout.pos_in_scrolling_layout | length) == 2
                and .layout.pos_in_scrolling_layout[0] == $target_column
              )
            | {
                id: .id,
                row: .layout.pos_in_scrolling_layout[1]
              }
          ]
        | sort_by([
            ((.row - $current_row) * (.row - $current_row)),
            .row
          ])
        | if length == 0 then
            { kind: "none" }
          else
            { kind: "tiled", id: .[0].id }
          end
      end
  end
' <<<"$windows_response") || {
  notify 'Window focus failed' 'Could not determine the nearest window in the adjacent column.'
  exit 1
}

focus_kind=$(jq -er '.kind' <<<"$focus_result")

case "$focus_kind" in
  none)
    exit 0
    ;;
  floating)
    niri msg action "focus-column-$direction" >/dev/null
    ;;
  tiled)
    target_id=$(jq -er '.id | numbers' <<<"$focus_result")
    if ! niri msg action focus-window --id "$target_id" >/dev/null; then
      notify 'Window focus failed' 'The adjacent window could not be focused.'
      exit 1
    fi
    ;;
  *)
    printf 'niri-focus-adjacent-window: unexpected result kind: %s\n' "$focus_kind" >&2
    exit 1
    ;;
esac
