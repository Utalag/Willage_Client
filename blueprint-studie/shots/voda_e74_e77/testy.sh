#!/bin/bash
# použití: vt_run.sh STAGE  (běží ve /workspace/wt-voda)
S=$1; O=/tmp/vt/$S; mkdir -p $O
G=/workspace/tools/Godot_v4.7.2-stable_linux.x86_64
R=${R:-$(git rev-parse --show-toplevel)}
P=$R/godot-prototyp; B=$R/blueprint-studie
run() { # name dir args...
  local n=$1 d=$2; shift 2
  if [ -n "$ONLY" ] && ! [[ $n =~ $ONLY ]]; then return; fi
  ( cd $d && t0=$(date +%s); timeout 1500 $G --headless --path . -s "$@" > $O/$n.txt 2>&1; echo "exit $? za $(( $(date +%s) - t0 )) s" >> $O/$n.txt )
}
N=${PAR:-4}
jobs_wait() { while [ $(jobs -r | wc -l) -ge $N ]; do sleep 1; done; }
run e66_vychozi $P tools/voda_e66.gd -- --vykopu=12 --kontrola=1 --out=$O/e66_vychozi.json & jobs_wait
run e66_obracene $P tools/voda_e66.gd -- --vykopu=12 --kontrola=1 --poradi=obracene --out=$O/e66_obracene.json & jobs_wait
run e66_e67 $P tools/voda_e66.gd -- --vykopu=12 --kontrola=1 --bp.voda_e67=true --out=$O/e66_e67.json & jobs_wait
run e66_e67_obr $P tools/voda_e66.gd -- --vykopu=12 --kontrola=1 --poradi=obracene --bp.voda_e67=true --out=$O/e66_e67_obr.json & jobs_wait
run e68_auto $B tools/e68.gd -- --kola=200 --rezim=auto --out=$O/e68_auto.json & jobs_wait
run e68_pretok $B tools/e68.gd -- --kola=200 --rezim=pretok --out=$O/e68_pretok.json & jobs_wait
run e68_auto05 $B tools/e68.gd -- --kola=200 --rezim=auto --zdroj=0.05 --out=$O/e68_auto05.json & jobs_wait
run e68_pretok05 $B tools/e68.gd -- --kola=200 --rezim=pretok --zdroj=0.05 --out=$O/e68_pretok05.json & jobs_wait
run e74_vyzv $P tools/gw_e74.gd -- --vykopu=12 --hloubka=2 --kontrola=1 --bp.p74_gw=true --bp.p74_vyzvednout=true --out=$O/e74_vyzv.json & jobs_wait
run e74_vyzv_obr $P tools/gw_e74.gd -- --vykopu=12 --hloubka=2 --kontrola=1 --poradi=obracene --bp.p74_gw=true --bp.p74_vyzvednout=true --out=$O/e74_vyzv_obr.json & jobs_wait
run e68_vyzv $B tools/e68.gd -- --kola=200 --rezim=auto --bp.p74_vyzvednout=true --out=$O/e68_vyzv.json & jobs_wait
run e69 $B tools/e69.gd -- & jobs_wait
run e72_ostrov $B tools/e67.gd -- --vykopu=12 --out=$O/e72_ostrov.json & jobs_wait
run e74 $P tools/gw_e74.gd -- --vykopu=12 --hloubka=2 --kontrola=1 --bp.p74_gw=true --out=$O/e74.json & jobs_wait
run e74_e67 $P tools/gw_e74.gd -- --vykopu=12 --hloubka=2 --kontrola=1 --bp.p74_gw=true --bp.voda_e67=true --out=$O/e74_e67.json & jobs_wait
run e75_syn $B tools/e75.gd -- --out=$O/e75_syn.json & jobs_wait
run e75_ostrov $P tools/kras_e75.gd -- --bp.p75_kras=true --vykopu=12 --udalosti=4 --dni=365 --out=$O/e75_ostrov.json & jobs_wait
run e76 $P tools/prenos_e76.gd -- --out=$O/e76.json & jobs_wait
run e76_p76 $P tools/prenos_e76.gd -- --bp.p76_prameny=true --out=$O/e76_p76.json & jobs_wait
run e77 $P tools/cas_e77.gd -- --out=$O/e77.json & jobs_wait
wait
cp $B/shots/e69/vysledky.json $O/e69.json 2>/dev/null
cd $R && git checkout -q -- blueprint-studie/shots godot-prototyp/shots 2>/dev/null
git -C $R status --short | grep -v "^??" | head
echo HOTOVO $S
