#!/usr/bin/env bash
# Parse-checks every script and runs the headless harnesses with Godot 4.3.
# Usage: tools/headless/run.sh            (needs `godot` on PATH, or GODOT=/path/to/godot)
#        tools/headless/run.sh --download (fetches Godot 4.3 into .godot-bin/ first)
set -euo pipefail
cd "$(dirname "$0")/../.."

if [[ "${1:-}" == "--download" ]]; then
    mkdir -p .godot-bin
    if [[ ! -x .godot-bin/Godot_v4.3-stable_linux.x86_64 ]]; then
        curl -sSL -o .godot-bin/godot.zip https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip
        (cd .godot-bin && unzip -oq godot.zip && rm godot.zip)
    fi
    GODOT=.godot-bin/Godot_v4.3-stable_linux.x86_64
fi
GODOT="${GODOT:-godot}"

echo "== import"
timeout 180 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== parse check"
fail=0
for f in scripts/core/*.gd scripts/football/*.gd scripts/ui/*.gd; do
    out=$(timeout 60 "$GODOT" --headless --path . --check-only -s "$f" 2>&1 | grep -iE "error|warning" || true)
    if [[ -n "$out" ]]; then echo "--- $f"; echo "$out"; fail=1; fi
done
[[ $fail -eq 0 ]] && echo "all scripts parse clean"

run() {
    local name="$1"; shift
    echo "== $name"
    timeout 900 "$GODOT" --headless --path . --fixed-fps 60 -s "res://tools/headless/$name.gd" -- "$@" 2>&1 | grep -vE "^Godot Engine|^$" | tail -n 25
}

run season_test
run offseason_test
run save_test
run battle_test 3 2
run battle_test 1 1
run season_flow_test 3 3
run offseason_flow_test
run save_flow_test
