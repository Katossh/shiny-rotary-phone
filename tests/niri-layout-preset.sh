#!/usr/bin/env bash
set -Eeuo pipefail

script=${1:?usage: test-niri-layout-preset.sh PATH_TO_SCRIPT}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat >"$test_root/bin/niri" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$1" == msg && "$2" == --json && "$3" == workspaces ]]; then
  cat "$NIRI_WORKSPACES_JSON"
elif [[ "$1" == msg && "$2" == --json && "$3" == windows ]]; then
  cat "$NIRI_WINDOWS_JSON"
elif [[ "$1" == msg && "$2" == action ]]; then
  shift 2
  printf '%s\n' "$*" >>"$NIRI_ACTION_LOG"
else
  printf 'Unexpected mock niri invocation: %s\n' "$*" >&2
  exit 90
fi
MOCK
chmod +x "$test_root/bin/niri"

cat >"$test_root/bin/notify-send" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$test_root/bin/notify-send"

export PATH="$test_root/bin:$PATH"
export NIRI_WORKSPACES_JSON="$test_root/workspaces.json"
export NIRI_WINDOWS_JSON="$test_root/windows.json"
export NIRI_ACTION_LOG="$test_root/actions.log"

write_fixture() {
  cat >"$NIRI_WORKSPACES_JSON" <<'JSON'
[{"id":7,"is_focused":true}]
JSON
}

write_windows() {
  local count=$1
  local focused_index=$2
  local floating=${3:-false}
  jq -n --argjson count "$count" --argjson focused_index "$focused_index" --argjson floating "$floating" '
    [
      [range(1; $count + 1) as $column | {
        id: (100 + $column), workspace_id: 7,
        is_focused: ($column == $focused_index), is_floating: false,
        layout: {pos_in_scrolling_layout: [$column, 1]}
      }]
      + (if $floating then [{
          id: 199, workspace_id: 7, is_focused: false, is_floating: true,
          layout: {pos_in_scrolling_layout: null}
        }] else [] end)
    ]
    | add
  ' >"$NIRI_WINDOWS_JSON"
}

assert_contains() {
  local needle=$1
  local haystack=$2
  if ! grep -Fq -- "$needle" <<<"$haystack"; then
    printf 'Expected to find: %s\nIn:\n%s\n' "$needle" "$haystack" >&2
    exit 1
  fi
}

assert_equals() {
  local expected=$1
  local actual=$2
  if [[ "$expected" != "$actual" ]]; then
    printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

run_width_test() {
  local preset=$1
  local count=$2
  local focus_index=$3
  local expected_widths=$4
  write_fixture
  write_windows "$count" "$focus_index"
  : >"$NIRI_ACTION_LOG"
  bash "$script" "$preset" >/dev/null
  local actual_widths
  actual_widths=$(grep '^set-column-width ' "$NIRI_ACTION_LOG" | sed 's/^set-column-width //' | paste -sd '|' -)
  assert_equals "$expected_widths" "$actual_widths"
}

# Mod+Alt+1 prioritizes the focused window and groups every other tiled
# window into a tabbed side column. All tiled windows are retained.
write_fixture
write_windows 5 3
: >"$NIRI_ACTION_LOG"
output=$(bash "$script" focus-stack)
assert_contains 'Applied Main + tab stack (65 / 35) to 5 tiled windows.' "$output"
actual=$(cat "$NIRI_ACTION_LOG")
expected_actions=$(cat <<'ACTIONS'
focus-window --id 103
move-column-to-first
focus-column 2
move-column-to-last
focus-column 2
move-column-to-last
focus-column 1
set-column-width 65%
set-column-display normal
reset-window-height --id 103
focus-column 2
consume-window-into-column
consume-window-into-column
consume-window-into-column
set-column-width 35%
set-column-display tabbed
reset-window-height --id 104
reset-window-height --id 105
reset-window-height --id 101
reset-window-height --id 102
focus-window --id 103
ACTIONS
)
assert_contains "$expected_actions" "$actual"
consume_count=$(grep -c 'consume-window-into-column' "$NIRI_ACTION_LOG" || true)
if [[ "$consume_count" -ne 3 ]]; then
  echo "Expected all four side windows to be grouped into one tabbed column." >&2
  exit 1
fi

# Numeric presets 2–4 correspond directly to their visible window counts.
run_width_test double 5 2 '50%|50%'
run_width_test triple 6 1 '33.333333%|33.333333%|33.333333%'
run_width_test quad 6 4 '25%|25%|25%|25%'

# Main + references: the focused window is central, with its immediate
# neighbors placed on the left and right. Other windows remain after the trio.
write_fixture
write_windows 5 3
: >"$NIRI_ACTION_LOG"
output=$(bash "$script" references)
assert_contains 'Applied Main centered (20 / 60 / 20) to 3 of 5 tiled windows; 2 extra windows remain to the right.' "$output"
actual=$(cat "$NIRI_ACTION_LOG")
assert_contains $'focus-window --id 102\nmove-column-to-first\nfocus-column 2\nmove-column-to-last\nfocus-column 1\nset-column-width 20%\nset-column-display normal\nreset-window-height --id 102\nfocus-column 2\nset-column-width 60%\nset-column-display normal\nreset-window-height --id 103\nfocus-column 3\nset-column-width 20%\nset-column-display normal\nreset-window-height --id 104\nfocus-window --id 103' "$actual"
if grep -Eq 'reset-window-height --id 101|reset-window-height --id 105' <<<"$actual"; then
  printf 'Non-selected reference windows were modified:\n%s\n' "$actual" >&2
  exit 1
fi

# Wraparound still leaves the main window in the middle when it is first.
write_fixture
write_windows 4 1
: >"$NIRI_ACTION_LOG"
bash "$script" references >/dev/null
actual=$(cat "$NIRI_ACTION_LOG")
assert_contains 'reset-window-height --id 104' "$actual"
assert_contains 'reset-window-height --id 101' "$actual"
assert_contains 'reset-window-height --id 102' "$actual"
assert_contains 'focus-window --id 101' "$actual"
if grep -Fq 'reset-window-height --id 103' <<<"$actual"; then
  printf 'Surplus window was included in the centered reference layout:\n%s\n' "$actual" >&2
  exit 1
fi

# Floating windows are ignored when counting and selecting tiled windows.
write_fixture
write_windows 3 2 true
: >"$NIRI_ACTION_LOG"
output=$(bash "$script" triple)
assert_contains 'Applied Triple (33.33 / 33.33 / 33.33) to 3 tiled windows.' "$output"
if grep -Fq -- '--id 199' "$NIRI_ACTION_LOG"; then
  printf 'Floating window was modified:\n%s\n' "$(cat "$NIRI_ACTION_LOG")" >&2
  exit 1
fi

# The script also accepts the older wrapped IPC response shape.
cat >"$NIRI_WORKSPACES_JSON" <<'JSON'
{"Ok":{"Workspaces":[{"id":7,"is_focused":true}]}}
JSON
cat >"$NIRI_WINDOWS_JSON" <<'JSON'
{"Ok":{"Windows":[
  {"id":101,"workspace_id":7,"is_focused":true,"is_floating":false,"layout":{"pos_in_scrolling_layout":[1,1]}},
  {"id":102,"workspace_id":7,"is_focused":false,"is_floating":false,"layout":{"pos_in_scrolling_layout":[2,1]}},
  {"id":103,"workspace_id":7,"is_focused":false,"is_floating":false,"layout":{"pos_in_scrolling_layout":[3,1]}}
]}}
JSON
: >"$NIRI_ACTION_LOG"
bash "$script" triple >/dev/null
assert_contains 'set-column-width 33.333333%' "$(cat "$NIRI_ACTION_LOG")"

# Too few tiled windows must fail before issuing any mutating action.
write_fixture
write_windows 2 1
: >"$NIRI_ACTION_LOG"
if bash "$script" triple >/dev/null 2>&1; then
  echo 'Expected a window-count mismatch to fail.' >&2
  exit 1
fi
if [[ -s "$NIRI_ACTION_LOG" ]]; then
  printf 'Preset mutated windows despite too few windows:\n%s\n' "$(cat "$NIRI_ACTION_LOG")" >&2
  exit 1
fi

printf 'Niri layout preset tests passed.\n'
