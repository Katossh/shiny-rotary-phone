#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  printf 'Usage: niri-move-window-workspace {window|column} {previous|next}\n' >&2
}

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name='Niri workspace movement' "$1" "$2" >/dev/null 2>&1 || true
  fi
}

if (($# != 2)); then
  usage
  exit 2
fi

case "$1" in
  window) action=move-window-to-workspace ;;
  column) action=move-column-to-workspace ;;
  *)
    usage
    exit 2
    ;;
esac

case "$2" in
  previous) direction=previous ;;
  next) direction=next ;;
  *)
    usage
    exit 2
    ;;
esac

command -v niri >/dev/null 2>&1 || {
  printf 'niri-move-window-workspace: niri was not found in PATH.\n' >&2
  exit 1
}

workspace_response=$(niri msg --json workspaces) || {
  notify 'Workspace movement failed' 'Could not query Niri workspaces.'
  exit 1
}
workspace_list=$(jq -ce '
  if type == "array" then .
  elif (.Ok.Workspaces | type) == "array" then .Ok.Workspaces
  elif (.Workspaces | type) == "array" then .Workspaces
  else error("Niri did not return a workspace array")
  end
' <<<"$workspace_response") || {
  notify 'Workspace movement failed' 'Could not read the Niri workspace list.'
  exit 1
}

current_name=$(jq -er '
  map(select(.is_focused == true))
  | .[0].name // empty
' <<<"$workspace_list") || {
  notify 'Workspace movement skipped' 'The focused workspace is not one of the five named workspaces.'
  exit 0
}

# Keep directional movement inside the five persistent named workspaces.
# In particular, do not move from workspace 5 into Niri's dynamic trailing
# workspace: Niri would create another empty workspace after it.
case "$current_name:$direction" in
  1:next) target=2 ;;
  2:previous) target=1 ;;
  2:next) target=3 ;;
  3:previous) target=2 ;;
  3:next) target=4 ;;
  4:previous) target=3 ;;
  4:next) target=5 ;;
  5:previous) target=4 ;;
  1:previous|5:next)
    exit 0
    ;;
  *)
    notify 'Workspace movement skipped' "Focused workspace '$current_name' is outside the five named workspaces."
    exit 0
    ;;
esac

if ! niri msg action "$action" "$target" >/dev/null; then
  notify 'Workspace movement failed' "Could not move the focused window to workspace $target."
  exit 1
fi
