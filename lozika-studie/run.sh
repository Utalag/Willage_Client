#!/bin/sh
# Studie ložisek a žil (ore-v0) a jeskyní s vodou (cave-v0).
# Použití: ./run.sh vectors | stress | bench | shots | caves | cave-sim | cave-stress | cave-shots | gen3 | gen3-stress | gen3-sim | gen3-ablation | gen3-shots
cd "$(dirname "$0")"
GODOT=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
MODE=${1:-shots}; shift 2>/dev/null
case "$MODE" in
  vectors|stress|bench|caves|cave-sim|cave-stress|gen3|gen3-stress|gen3-sim|gen3-ablation)
    timeout 900 "$GODOT" --headless --path . -- --$MODE "$@" ;;
  cave-shots|gen3-shots)
    timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --$MODE "$@" ;;
  *)
    timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --shots "$@" ;;
esac
