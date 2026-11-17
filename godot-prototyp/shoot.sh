#!/bin/sh
# Spustí demo bez okna (virtuální displej + OpenGL) a uloží screenshoty 1280 × 800 do shots/.
cd "$(dirname "$0")"
GODOT=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
timeout 180 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . -- --demo
