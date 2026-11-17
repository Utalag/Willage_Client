#!/bin/sh
# Studie vody a propustnosti. Spuštění bez okna (virtuální displej + OpenGL).
# Použití: ./run.sh shots | bench | play  [-- další parametry, např. --scen=5 --perm_sand=0.5]
cd "$(dirname "$0")"
GODOT=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
MODE=${1:-shots}; shift 2>/dev/null
case "$MODE" in
  bench)
    timeout 900 "$GODOT" --headless --path . -- --bench "$@" ;;
  play)
    "$GODOT" --path . -- "$@" ;;
  *)
    timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x720 -- --$MODE "$@" ;;
esac
