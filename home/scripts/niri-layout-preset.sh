set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: niri-layout-preset PRESET

Apply a layout to tiled windows on the focused Niri workspace.
PRESET is one of: focus-stack, double, triple, quad, references.
USAGE
}

notify() {
  local title=$1
  local message=$2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name='Niri layout' "$title" "$message" >/dev/null 2>&1 || true
  fi
}

fail() {
  printf 'niri-layout-preset: %s\n' "$1" >&2
  notify 'Layout not applied' "$1"
  exit 1
}

run_action() {
  if ! niri msg action "$@" >/dev/null; then
    fail "Niri rejected action: $*. The layout may be partially changed."
  fi
}

if (($# != 1)); then
  usage >&2
  exit 2
fi

case "$1" in
  focus-stack)
    preset_name='Main + tab stack (65 / 35)'
    widths=(65 35)
    group_sizes=()
    display_modes=(normal tabbed)
    minimum_count=2
    expected_count=0
    focus_offset=0
    selection_mode=all
    ;;
  double)
    preset_name='Double (50 / 50)'
    widths=(50 50)
    group_sizes=(1 1)
    display_modes=(normal normal)
    minimum_count=2
    expected_count=2
    focus_offset=0
    selection_mode=preset
    ;;
  triple)
    preset_name='Triple (33.33 / 33.33 / 33.33)'
    widths=(33.333333 33.333333 33.333333)
    group_sizes=(1 1 1)
    display_modes=(normal normal normal)
    minimum_count=3
    expected_count=3
    focus_offset=0
    selection_mode=preset
    ;;
  quad)
    preset_name='Quad (25 / 25 / 25 / 25)'
    widths=(25 25 25 25)
    group_sizes=(1 1 1 1)
    display_modes=(normal normal normal normal)
    minimum_count=4
    expected_count=4
    focus_offset=0
    selection_mode=preset
    ;;
  references)
    preset_name='Main centered (20 / 60 / 20)'
    widths=(20 60 20)
    group_sizes=(1 1 1)
    display_modes=(normal normal normal)
    minimum_count=3
    expected_count=3
    focus_offset=1
    selection_mode=preset
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    fail "Unknown preset: $1"
    ;;
esac

command -v niri >/dev/null 2>&1 || fail 'niri was not found in PATH.'

workspace_response=$(niri msg --json workspaces) || fail 'Could not query Niri workspaces.'
workspace_list=$(jq -ce '
  if type == "array" then .
  elif (.Ok.Workspaces | type) == "array" then .Ok.Workspaces
  elif (.Workspaces | type) == "array" then .Workspaces
  else error("Niri did not return a workspace array")
  end
' <<<"$workspace_response") || fail 'Could not read the Niri workspace list.'
workspace_id=$(jq -er 'map(select(.is_focused == true)) | .[0].id // empty' <<<"$workspace_list") \
  || fail 'Could not identify the focused workspace.'

windows_response=$(niri msg --json windows) || fail 'Could not query Niri windows.'
windows_list=$(jq -ce '
  if type == "array" then .
  elif (.Ok.Windows | type) == "array" then .Ok.Windows
  elif (.Windows | type) == "array" then .Windows
  else error("Niri did not return a window array")
  end
' <<<"$windows_response") || fail 'Could not read the Niri window list.'
window_ids_output=$(jq -r --argjson workspace_id "$workspace_id" '
  map(select(
      .workspace_id == $workspace_id
      and .is_floating == false
      and (.layout.pos_in_scrolling_layout | type == "array")
    ))
  | sort_by(.layout.pos_in_scrolling_layout[0], .layout.pos_in_scrolling_layout[1])
  | .[].id
' <<<"$windows_list") || fail 'Could not read tiled window positions from Niri.'

window_ids=()
window_count=0
if [[ -n "$window_ids_output" ]]; then
  mapfile -t window_ids <<<"$window_ids_output"
  window_count=${#window_ids[@]}
fi

if ((window_count < minimum_count)); then
  fail "$preset_name needs at least $minimum_count tiled windows on this workspace; found $window_count. No windows were moved."
fi

# The focus-stack preset keeps every tiled window: the focused window is the
# main column, and all remaining windows become tabs in the right-hand column.
if [[ "$selection_mode" == all ]]; then
  expected_count=$window_count
  group_sizes=(1 $((window_count - 1)))
fi

# Anchor the preset on the focused window. Most presets start there;
# the centered-reference preset starts with its left-hand reference instead.
focused_id=$(jq -er --argjson workspace_id "$workspace_id" '
  map(select(
    .workspace_id == $workspace_id
    and .is_focused == true
    and .is_floating == false
    and (.layout.pos_in_scrolling_layout | type == "array")
  ))
  | .[0].id // empty
' <<<"$windows_list") || fail 'Focus a tiled window before applying a layout preset.'

focused_index=-1
for index in "${!window_ids[@]}"; do
  if [[ "${window_ids[$index]}" == "$focused_id" ]]; then
    focused_index=$index
    break
  fi
done
if ((focused_index < 0)); then
  fail 'Could not locate the focused window in the tiled workspace.'
fi

# focus_offset is zero for ordinary presets and one for Main + references:
# [previous window, focused main window, next window].
anchor_index=$(((focused_index - focus_offset + window_count) % window_count))
ordered_window_ids=("${window_ids[@]:$anchor_index}" "${window_ids[@]:0:$anchor_index}")
window_ids=("${ordered_window_ids[@]}")

mapfile -t original_columns < <(jq -r --argjson workspace_id "$workspace_id" '
  .
  | map(select(
      .workspace_id == $workspace_id
      and .is_floating == false
      and (.layout.pos_in_scrolling_layout | type == "array")
    ))
  | map(.layout.pos_in_scrolling_layout[0])
  | unique
  | reverse
  | .[]
' <<<"$windows_list")

# Flatten existing stacks from right to left. Expelling bottom tiles creates
# adjacent columns, preserving the visual left-to-right/top-to-bottom order.
for column in "${original_columns[@]}"; do
  column_ids=$(jq -r --argjson workspace_id "$workspace_id" --argjson column "$column" '
    .
    | map(select(
        .workspace_id == $workspace_id
        and .is_floating == false
        and .layout.pos_in_scrolling_layout[0] == $column
      ))
    | sort_by(.layout.pos_in_scrolling_layout[1])
    | .[].id
  ' <<<"$windows_list")
  mapfile -t ids_in_column <<<"$column_ids"
  if ((${#ids_in_column[@]} > 1)); then
    run_action focus-window --id "${ids_in_column[0]}"
    for ((index = 1; index < ${#ids_in_column[@]}; index++)); do
      run_action expel-window-from-column
    done
  fi
done

# Move the anchor window to the first column, then rotate the columns
# before it to the end. This makes the compositor order match window_ids.
anchor_id=${window_ids[0]}
run_action focus-window --id "$anchor_id"
run_action move-column-to-first
for ((index = 0; index < anchor_index; index++)); do
  run_action focus-column 2
  run_action move-column-to-last
done

# Rebuild the target column groups from left to right.
window_offset=0
target_column=1
for index in "${!group_sizes[@]}"; do
  group_size=${group_sizes[$index]}
  run_action focus-column "$target_column"

  for ((tile = 1; tile < group_size; tile++)); do
    run_action consume-window-into-column
  done

  run_action set-column-width "${widths[$index]}%"
  run_action set-column-display "${display_modes[$index]}"

  for ((tile = 0; tile < group_size; tile++)); do
    run_action reset-window-height --id "${window_ids[$((window_offset + tile))]}"
  done

  ((window_offset += group_size))
  ((target_column += 1))
done

# Keep the user's original focused window selected after the transformation.
if [[ -n "$focused_id" ]]; then
  run_action focus-window --id "$focused_id"
fi

if ((window_count > expected_count)); then
  extra_count=$((window_count - expected_count))
  notify 'Layout applied' "$preset_name — $extra_count extra window(s) left to the right."
  printf 'Applied %s to %d of %d tiled windows; %d extra windows remain to the right.\n' \
    "$preset_name" "$expected_count" "$window_count" "$extra_count"
else
  notify 'Layout applied' "$preset_name"
  printf 'Applied %s to %d tiled windows.\n' "$preset_name" "$window_count"
fi