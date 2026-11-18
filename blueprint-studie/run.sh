#!/bin/sh
# Blueprint-studie: navázání vrstev a povrchu na sousedy. Použití: ./run.sh shots | test | play | horniny | horniny-test  [--klic=hodnota …]
cd "$(dirname "$0")"
GODOT=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
MODE=${1:-shots}; shift 2>/dev/null
case "$MODE" in
  test) timeout 900 "$GODOT" --headless --path . -s res://tools/test.gd -- "$@" ;;
  play) "$GODOT" --path . -- "$@" ;;
  horniny) timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --horniny "$@" && python3 tools/compose_shots.py ;;
  horniny-test) timeout 900 "$GODOT" --headless --path . -s res://tools/test_horniny.gd -- "$@" ;;
  *) timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --shots "$@" ;;
esac
