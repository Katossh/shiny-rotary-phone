#!/usr/bin/env bash
set -Eeuo pipefail

script=${1:?usage: test-niri-focus-adjacent-window.sh PATH_TO_SCRIPT}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat >"$test_root/bin/niri" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$1" == msg && "$2" == --json && "$3" == windows ]]; then
  cat "$NIRI_WINDOWS_JSON"
elif [[ "$1" == msg && "$2" == action && "$3" == focus-window && "$4" == --id ]]; then
  printf 'focus-window %s\n' "$5" >>"$NIRI_ACTION_LOG"
elif [[ "$1" == msg && "$2" == action && "$3" == focus-column-left ]]; then
  printf 'native-focus-left\n' >>"$NIRI_ACTION_LOG"
elif [[ "$1" == msg && "$2" == action && "$3" == focus-column-right ]]; then
  printf 'native-focus-right\n' >>"$NIRI_ACTION_LOG"
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
export NIRI_WINDOWS_JSON="$test_root/windows.json"
export NIRI_ACTION_LOG="$test_root/actions.log"

write_windows() {
  local focused_id=$1
  jq -n --argjson focused_id "$focused_id" '
    def tile($id; $column; $row; $workspace):
      {
        id: $id,
        workspace_id: $workspace,
        is_focused: ($id == $focused_id),
        is_floating: false,
        layout: {
          pos_in_scrolling_layout: [$column, $row]
        }
      };

    [
      tile(11; 1; 1; 1),
      tile(12; 1; 2; 1),
      tile(21; 2; 1; 1),
      tile(22; 2; 2; 1),
      # A matching position on another workspace must never be selected.
      tile(32; 1; 2; 2),
      {
        id: 99,
        workspace_id: 1,
        is_focused: ($focused_id == 99),
        is_floating: true,
        layout: { pos_in_scrolling_layout: null }
      }
    ]
  ' >"$NIRI_WINDOWS_JSON"
}

assert_equals() {
  local expected=$1
  local actual=$2
  if [[ "$expected" != "$actual" ]]; then
    printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

run_focus_test() {
  local focused_id=$1
  local direction=$2
  local expected=$3
  write_windows "$focused_id"
  : >"$NIRI_ACTION_LOG"
  bash "$script" "$direction" >/dev/null
  assert_equals "$expected" "$(cat "$NIRI_ACTION_LOG")"
}

# Horizontal focus preserves the vertical tile index in a 2×2 arrangement.
# The left column's previously focused tile is deliberately irrelevant.
run_focus_test 22 left 'focus-window 12'
run_focus_test 21 left 'focus-window 11'
run_focus_test 12 right 'focus-window 22'
run_focus_test 11 right 'focus-window 21'

# If the adjacent column has fewer windows, choose its closest available row.
run_focus_test 22 left 'focus-window 12'

# Do not cross workspace boundaries or select windows from another workspace.
run_focus_test 11 left ''
run_focus_test 12 left ''

# Preserve native directional focus for floating windows.
run_focus_test 99 left 'native-focus-left'
run_focus_test 99 right 'native-focus-right'

# Do nothing when no window currently owns keyboard focus.
run_focus_test -1 left ''

printf 'Niri adjacent-window focus tests passed.\n'
