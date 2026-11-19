#!/bin/sh
# E52: všechny varianty podzemí, každá ve vlastním procesu (peak paměti patří jen jí), pak tabulka + snímky.
cd "$(dirname "$0")/.."
G=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
R="timeout 1800 $G --headless --path . -s res://tools/test_podzemi52.gd --"
[ -f .cache52/svet64.bin ] || timeout 1800 "$G" --headless --path . -s res://tools/cache_podzemi52.gd "$@"
mkdir -p shots/podzemi52 && rm -f shots/podzemi52/*.json shots/podzemi52/beh.log
L=shots/podzemi52/beh.log
$R --p52_var=testy "$@" | tail -6 >> $L
for a in \
  "--p52_var=slovnik --p52_ug_n=64" \
  "--p52_var=pole --p52_ug_n=64" \
  "--p52_var=pole --p52_ug_n=64 --p52_hloubka_m=0" \
  "--p52_var=slovnik --p52_ug_n=32" \
  "--p52_var=pole --p52_ug_n=32" \
  "--p52_var=pole --p52_ug_n=16" \
  "--p52_var=funkce --p52_rezim=nadrz --p52_ug_n=64" \
  "--p52_var=funkce --p52_rezim=preliv --p52_ug_n=64" \
  "--p52_var=funkce --p52_rezim=darcy --p52_ug_n=64" \
  "--p52_var=funkce --p52_rezim=darcy --p52_ug_n=64 --p52_darcy_k=0.01" \
  "--p52_var=funkce --p52_rezim=nadrz --p52_ug_n=32" \
  "--p52_var=funkce --p52_rezim=nadrz --p52_ug_n=16" \
  "--p52_var=funkce --p52_rezim=nadrz --s64_voda_n=32 --p52_ug_n=32" \
  "--p52_var=funkce --p52_rezim=nadrz --s64_voda_n=16 --p52_ug_n=16" \
  "--p52_var=pole --s64_voda_n=32 --p52_ug_n=32" \
  "--p52_var=pole --s64_voda_n=16 --p52_ug_n=16" \
  "--p52_var=povrch --s64_voda_n=16 --vodopad_dx_m=0" "--p52_var=povrch --s64_voda_n=16" \
  "--p52_var=povrch --s64_voda_n=32 --vodopad_dx_m=0" "--p52_var=povrch --s64_voda_n=32" \
  "--p52_var=povrch --s64_voda_n=64 --vodopad_dx_m=0" "--p52_var=povrch --s64_voda_n=64"; do
  $R $a "$@" | grep -v "^Godot Engine" | grep -v "^$" >> $L
done
python3 tools/podzemi52.py
