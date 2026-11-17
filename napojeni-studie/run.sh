#!/bin/sh
# Spuštění bez okna (virtuální displej + OpenGL). Použití: ./run.sh shots | movie | bench | play  [-- další parametry]
cd "$(dirname "$0")"
GODOT=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
MODE=${1:-shots}; shift 2>/dev/null
XV='xvfb-run -a -s "-screen 0 1280x800x24"'
case "$MODE" in
  movie)
    rm -f shots/${OUT:-29_napojeni_demo}.avi
    timeout 1200 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . \
      --resolution 1280x720 --write-movie shots/${OUT:-29_napojeni_demo}.avi --fixed-fps 30 --quit-after ${FRAMES:-420} -- --movie "$@"
    ffmpeg -y -loglevel error -i shots/${OUT:-29_napojeni_demo}.avi -c:v libx264 -pix_fmt yuv420p -b:v 11M -maxrate 13M -bufsize 20M -preset slow shots/${OUT:-29_napojeni_demo}.mp4 && rm -f shots/${OUT:-29_napojeni_demo}.avi
    ls -la shots/${OUT:-29_napojeni_demo}.mp4 ;;
  mekkost)
    # 30_napojeni_mekkost_*: vzhled písku + řádky měkkosti hrany materiálu (ostrá / výchozí / měkká)
    timeout 600 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x720 -- --mekkost "$@"
    for v in "ostra 0.01 0.01" "vychozi 0.05 0.06" "mekka 0.20 0.25"; do set -- $v
      timeout 600 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x720 -- --hrana --tag=$1 --edge_soft=$2 --dual_soft=$3 >/dev/null 2>&1
    done
    ffmpeg -y -loglevel error -i shots/_hrana_ostra.png -i shots/_hrana_vychozi.png -i shots/_hrana_mekka.png -filter_complex vstack=inputs=3 shots/30_napojeni_mekkost_hrana.png && rm -f shots/_hrana_*.png
    ls shots/30_* ;;
  louka_voda)
    # 33_napojeni_louka_voda_*: louka přímo u vody (layout 1)
    timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x720 -- --louka_voda --layout=1 "$@" ;;
  samostatne)
    timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x720 -- --samostatne "$@" ;;
  play)
    "$GODOT" --path . -- "$@" ;;
  *)
    timeout 600 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x720 -- --$MODE "$@" ;;
esac
