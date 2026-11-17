#!/bin/sh
# Spuštění bez okna (virtuální displej + OpenGL). Použití: ./run.sh shots | movie | bench | play  [-- další parametry]
# Jiná scéna: SCENE=res://proc.tscn ./run.sh shots   (procedurální zem louky)
cd "$(dirname "$0")"
GODOT=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
MODE=${1:-shots}; shift 2>/dev/null
XV='xvfb-run -a -s "-screen 0 1280x800x24"'
case "$MODE" in
  movie)
    rm -f shots/${OUT:-trava_demo}.avi
    timeout 1200 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . \
      --resolution 1280x720 --write-movie shots/${OUT:-trava_demo}.avi --fixed-fps 30 --quit-after 360 -- --movie "$@"
    ffmpeg -y -loglevel error -i shots/${OUT:-trava_demo}.avi -c:v libx264 -pix_fmt yuv420p -b:v 11M -maxrate 13M -bufsize 20M -preset slow shots/${OUT:-trava_demo}.mp4 && rm -f shots/${OUT:-trava_demo}.avi
    ls -la shots/${OUT:-trava_demo}.mp4 ;;
  play)
    "$GODOT" --path . $SCENE -- "$@" ;;
  *)
    timeout 600 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . $SCENE --resolution 1280x720 -- --$MODE "$@" ;;
esac
