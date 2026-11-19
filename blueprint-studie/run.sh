#!/bin/sh
# Blueprint-studie: navázání vrstev a povrchu na sousedy. Použití: ./run.sh shots | test | play | horniny | horniny-test | voda | voda47b | voda47d | funkce | svet8 | svet64 | eroze51 | podzemi52 | plosne53 | dohnani54 | podzemi55 | svah56 | alg58 | e69  [--klic=hodnota …]
cd "$(dirname "$0")"
GODOT=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
MODE=${1:-shots}; shift 2>/dev/null
case "$MODE" in
  test) timeout 900 "$GODOT" --headless --path . -s res://tools/test.gd -- "$@" ;;
  play) "$GODOT" --path . -- "$@" ;;
  horniny) timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --horniny "$@" && python3 tools/compose_shots.py ;;
  voda47d) timeout 300 "$GODOT" --headless --path . -s res://tools/test_podzemi.gd && timeout 900 "$GODOT" --headless --path . -s res://tools/test_voda_b.gd -- "$@" && timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --voda47d "$@" ;;
  voda47b) timeout 300 "$GODOT" --headless --path . -s res://tools/test_tun.gd && timeout 900 "$GODOT" --headless --path . -s res://tools/test_voda_b.gd -- "$@" && timeout 900 "$GODOT" --headless --path . -s res://tools/test_voda_b.gd -- --b "$@" && timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --voda47b "$@" && (cd shots && ffmpeg -loglevel error -y -framerate 8 -i 47b_gif_%02d.png -vf "scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer" -loop 0 47b_vodopad.gif && rm 47b_gif_*.png) && python3 tools/compose_voda_b.py ;;
  voda) timeout 900 "$GODOT" --headless --path . -s res://tools/test_voda.gd -- "$@" && timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --voda "$@" && python3 tools/compose_voda.py ;;
  funkce) timeout 300 "$GODOT" --headless --path . -s res://tools/dump_funkce.gd -- "$@" && python3 tools/gif_funkce.py ;;
  svet8) timeout 900 "$GODOT" --headless --path . -s res://tools/test_svet8.gd -- "$@" && timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --svet8 "$@" && python3 tools/gif_svet8.py ;;
  svet64) rm -f shots/bench_svet64_render.txt && timeout 5400 "$GODOT" --headless --path . -s res://tools/test_svet64.gd -- "$@" && python3 tools/gif_svet64.py && timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --svet64 "$@" && cat shots/bench_svet64_render.txt >> shots/bench_svet64.txt ;;
  eroze51) timeout 900 "$GODOT" --headless --path . -s res://tools/test_eroze51.gd -- "$@" && python3 tools/shots_eroze51.py ;;
  podzemi52) sh tools/podzemi52.sh "$@" ;;
  alg58) sh tools/alg58.sh "$@" ;;
  alg60) sh tools/alg60.sh "$@" ;;
  e69) timeout 600 "$GODOT" --headless --path . -s res://tools/e69.gd -- "$@" ;;
  podzemi55) timeout 900 "$GODOT" --headless --path . -s res://tools/test_podzemi55.gd -- "$@" && python3 tools/shots_podzemi55.py ;;
  svah56) timeout 1200 "$GODOT" --headless --path . -s res://tools/svah56.gd -- "$@" && python3 tools/shots_svah56.py ;;
  dohnani54) timeout 900 "$GODOT" --headless --path . -s res://tools/test_dohnani54.gd -- "$@" ;;
  plosne53) timeout 2400 "$GODOT" --headless --path . -s res://tools/plosne53.gd -- "$@" && python3 tools/plosne53_np.py && python3 tools/shots_plosne53.py ;;
  horniny-test) timeout 900 "$GODOT" --headless --path . -s res://tools/test_horniny.gd -- "$@" ;;
  *) timeout 900 xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --rendering-driver opengl3 --path . --resolution 1280x800 -- --shots "$@" ;;
esac
