#!/bin/sh
# E60: (1) průsak světa jen z posledního kola (záznam _e60, base a A+B+C při 16 / 32 / 64), (2) povrch tok60 vs tok.update
# (profil + bit po bitu, 60 výkopů), (3) graf pánví B vs priority-flood bez ε, grafy shots/60_povrch.png.
G=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
for nv in 16 32 64; do
  timeout 900 "$G" --headless --path . -s res://tools/alg58_rec.gd -- --s64_voda_n=$nv --p52_ug_n=16 --p58_tag=_e60 "$@"
  for v in A+B+C base; do timeout 1500 "$G" --headless --path . -s res://tools/alg58_ug.gd -- --s64_voda_n=$nv --p52_ug_n=16 --p58_tag=_e60 --p58_var=$v "$@"; done
done
timeout 900 "$G" --headless --path . -s res://tools/alg60_tok.gd -- --s64_voda_n=64 --p60_mode=prof "$@"
for nv in 16 32 64; do timeout 1200 "$G" --headless --path . -s res://tools/alg60_tok.gd -- --s64_voda_n=$nv --p60_mode=fast --p58_edits=60 "$@"; done
for nv in 4 12; do timeout 900 "$G" --headless --path . -s res://tools/alg60_tok.gd -- --s64_voda_n=64 --p60_mode=fast --p60_m0=$nv "$@"; done
for nv in 16 32 64; do timeout 900 "$G" --headless --path . -s res://tools/alg60_b.gd -- --s64_voda_n=$nv "$@"; done
python3 tools/shots_alg60.py
