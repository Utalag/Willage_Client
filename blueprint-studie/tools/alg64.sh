#!/bin/sh
# E64: varianty K / I / R / V / P nad záznamem E61 (s16 / s32 / s64), po 4 souběžně. Výstup shots/e64/.
G=${GODOT:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
run() { nv=$1; v=$2; shift 2; tag=$(echo "$v" | tr -d '+' | sed 's/ABCD//'); timeout 1500 "$G" --headless --path . -s res://tools/alg64_ug.gd -- --s64_voda_n=$nv --p52_ug_n=16 --p58_var=$v "$@" 2>&1 | grep -v "^Godot\|WARN\|at: \|leaked\|resources still" > shots/e64/t${nv}_${tag}$(echo "$@" | tr -dc '0-9a-z_').log; }
J=0
for job in "64 A+B+C+D+K" "16 A+B+C+D+K" "32 A+B+C+D+K" \
           "16 A+B+C+D+K+I+R" "32 A+B+C+D+K+I+R" "64 A+B+C+D+K+I+R" \
           "16 A+B+C+D+K+I+V" "32 A+B+C+D+K+I+V" "64 A+B+C+D+K+I+V" \
           "16 A+B+C+D+K+I+R+V" "32 A+B+C+D+K+I+R+V" "64 A+B+C+D+K+I+R+V" \
           "16 A+B+C+D+K+I+P+R" "32 A+B+C+D+K+I+P+R" "64 A+B+C+D+K+I+P+R" \
           "16 A+B+C+D+K+I+P+R+V" "32 A+B+C+D+K+I+P+R+V" "64 A+B+C+D+K+I+P+R+V" \
           "64 A+B+C+D+K+I+P+R --p64_budget=2000 --p64_tag=_b2000" "64 A+B+C+D+K+I+P+R --p64_budget=10000 --p64_tag=_b10000" \
           "16 A+B+C+D+K+I+P+R --p64_budget=2000 --p64_tag=_b2000" "16 A+B+C+D+K+I+P+R --p64_budget=10000 --p64_tag=_b10000"; do
  run $job &
  J=$((J+1)); if [ $J -ge 4 ]; then wait; J=0; fi
done
wait
