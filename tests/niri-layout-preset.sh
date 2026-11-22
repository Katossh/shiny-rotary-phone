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
{"Ok":{"Workspaces":[{"id":7,"is_focused":true}]}}
JSON
}

write_linear_fixture() {
  local count=$1
  local with_floating=${2:-false}
  jq -n --argjson count "$count" --argjson with_floating "$with_floating" '
    {Ok:{Windows:(
      [range(1; $count + 1) as $column | {
        id: (300 + $column), workspace_id: 7,
        is_focused: ($column == $count), is_floating: false,
        layout: {pos_in_scrolling_layout: [$column, 1]}
      }]
      + (if $with_floating then [{
          id: 399, workspace_id: 7, is_focused: false, is_floating: true,
          layout: {pos_in_scrolling_layout: null}
        }] else [] end)
    )}}
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
  local expected_widths=$2
  : >"$NIRI_ACTION_LOG"
  "$script" "$preset" >/dev/null
  local actual_widths
  actual_widths=$(grep '^set-column-width ' "$NIRI_ACTION_LOG" | sed 's/^set-column-width //')
  assert_equals "$expected_widths" "$actual_widths"
}

# Four initially separate windows: developer layout should stack windows 2+3.
write_fixture
cat >"$NIRI_WINDOWS_JSON" <<'JSON'
{"Ok":{"Windows":[
  {"id":101,"workspace_id":7,"is_focused":false,"is_floating":false,"layout":{"pos_in_scrolling_layout":[1,1]}},
  {"id":102,"workspace_id":7,"is_focused":true,"is_floating":false,"layout":{"pos_in_scrolling_layout":[2,1]}},
  {"id":103,"workspace_id":7,"is_focused":false,"is_floating":false,"layout":{"pos_in_scrolling_layout":[3,1]}},
  {"id":104,"workspace_id":7,"is_focused":false,"is_floating":false,"layout":{"pos_in_scrolling_layout":[4,1]}}
]}}
JSON
: >"$NIRI_ACTION_LOG"
output=$("$script" developer)
assert_contains 'Applied Developer (50 / 25 / 25) to 4 tiled windows.' "$output"
expected=$(cat <<'EXPECTED'
focus-column 1
set-column-width 50%
set-column-display normal
reset-window-height --id 101
focus-column 2
consume-window-into-column
set-column-width 25%
set-column-display normal
reset-window-height --id 102
reset-window-height --id 103
focus-column 3
set-column-width 25%
set-column-display normal
reset-window-height --id 104
focus-window 102
EXPECTED
)
actual=$(cat "$NIRI_ACTION_LOG")
assert_equals "$expected" "$actual"

# Existing vertical stack is flattened and rebuilt without changing window order.
write_fixture
cat >"$NIRI_WINDOWS_JSON" <<'JSON'
{"Ok":{"Windows":[
  {"id":201,"workspace_id":7,"is_floating":false,"is_focused":false,"layout":{"pos_in_scrolling_layout":[1,1]}},
  {"id":202,"workspace_id":7,"is_floating":false,"is_focused":false,"layout":{"pos_in_scrolling_layout":[1,2]}},
  {"id":203,"workspace_id":7,"is_floating":false,"is_focused":false,"layout":{"pos_in_scrolling_layout":[2,1]}},
  {"id":204,"workspace_id":7,"is_floating":false,"is_focused":true,"layout":{"pos_in_scrolling_layout":[3,1]}}
]}}
JSON
: >"$NIRI_ACTION_LOG"
"$script" asymmetric >/dev/null
actual=$(cat "$NIRI_ACTION_LOG")
assert_contains $'focus-window 201\nexpel-window-from-column\nfocus-column 1\nconsume-window-into-column\nset-column-width 25%' "$actual"
assert_contains 'set-column-width 37.5%' "$actual"
assert_contains 'focus-window 204' "$actual"

# Floating windows are ignored; each preset must produce its declared column widths.
write_linear_fixture 3 true
run_width_test triple $'33.333333%\n33.333333%\n33.333333%'
run_width_test references $'60%\n20%\n20%'
write_linear_fixture 4
run_width_test quad $'25%\n25%\n25%\n25%'

# A mismatched window count must fail before issuing any mutating action.
cat >"$NIRI_WINDOWS_JSON" <<'JSON'
{"Ok":{"Windows":[
  {"id":401,"workspace_id":7,"is_focused":false,"is_floating":false,"layout":{"pos_in_scrolling_layout":[1,1]}},
  {"id":402,"workspace_id":7,"is_focused":true,"is_floating":false,"layout":{"pos_in_scrolling_layout":[2,1]}}
]}}
JSON
: >"$NIRI_ACTION_LOG"
if "$script" triple >/dev/null 2>&1; then
  echo 'Expected a window-count mismatch to fail.' >&2
  exit 1
fi
if [[ -s "$NIRI_ACTION_LOG" ]]; then
  printf 'Preset mutated windows despite a count mismatch:\n%s\n' "$(cat "$NIRI_ACTION_LOG")" >&2
  exit 1
fi

printf 'Niri layout preset tests passed.\n'
