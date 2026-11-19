#!/bin/sh
# E58: záznam volání (16 / 32 / 64), všechny varianty podzemí při 64, base a A+B+C při 16 / 32, povrch 16 / 32 / 64, grafy.
G=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
for nv in 16 32 64; do timeout 900 "$G" --headless --path . -s res://tools/alg58_rec.gd -- --s64_voda_n=$nv --p52_ug_n=16 "$@"; done
for v in base A B C A+B A+C B+C A+B+C; do timeout 1200 "$G" --headless --path . -s res://tools/alg58_ug.gd -- --s64_voda_n=64 --p52_ug_n=16 --p58_var=$v "$@"; done
for nv in 16 32; do for v in base A+B+C; do timeout 1200 "$G" --headless --path . -s res://tools/alg58_ug.gd -- --s64_voda_n=$nv --p52_ug_n=16 --p58_var=$v "$@"; done; done
for nv in 16 32 64; do timeout 1500 "$G" --headless --path . -s res://tools/alg58_tok.gd -- --s64_voda_n=$nv "$@"; done
python3 tools/shots_alg58.py
