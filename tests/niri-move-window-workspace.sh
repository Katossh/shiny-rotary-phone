#!/usr/bin/env bash
set -Eeuo pipefail

script=${1:?usage: test-niri-move-window-workspace.sh PATH_TO_SCRIPT}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat >"$test_root/bin/niri" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$1" == msg && "$2" == --json && "$3" == workspaces ]]; then
  cat "$NIRI_WORKSPACES_JSON"
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
export NIRI_ACTION_LOG="$test_root/actions.log"

write_workspaces() {
  local focused_name=$1
  jq -n --arg focused_name "$focused_name" '
    [range(1; 6) as $number | {
      id: $number,
      idx: $number,
      name: ($number | tostring),
      is_focused: (($number | tostring) == $focused_name)
    }]
    + [{
      id: 6,
      idx: 6,
      name: null,
      is_focused: ($focused_name == "dynamic")
    }]
  ' >"$NIRI_WORKSPACES_JSON"
}

assert_equals() {
  local expected=$1
  local actual=$2
  if [[ "$expected" != "$actual" ]]; then
    printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

run_move_test() {
  local current=$1
  local direction=$2
  local expected=$3
  write_workspaces "$current"
  : >"$NIRI_ACTION_LOG"
  bash "$script" "$direction" >/dev/null
  assert_equals "$expected" "$(cat "$NIRI_ACTION_LOG")"
}

# Directional movement changes only the focused window's destination.
run_move_test 3 next 'move-window-to-workspace 4'
run_move_test 3 previous 'move-window-to-workspace 2'

# The movement is bounded by the five persistent workspaces.
run_move_test 1 previous ''
run_move_test 5 next ''

# Never move into Niri's automatically maintained dynamic trailing workspace.
run_move_test dynamic next ''

printf 'Niri named-workspace movement tests passed.\n'
