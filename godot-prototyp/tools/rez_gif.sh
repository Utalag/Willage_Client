#!/usr/bin/env bash
# Řezy po vrstvách → animovaný GIF (bez GPU, bez scény). Příklady:
#   tools/rez_gif.sh                                   # celý startovní ostrov, krok 2 → shots/rez/ostrov.gif
#   tools/rez_gif.sh --oblast=0,0 --krok=2 --ms=500 --out=shots/rez/blok_0_0.gif
#   tools/rez_gif.sh --bloky="0,0:hora:7" --oblast=0,0 --podzemi=0
# Volby: --oblast=vse|x,y (slot bloku), --krok=N (výchozí 2), --ms=N (doba snímku, výchozí 750 ms), --out=cesta.gif,
#        --bloky="x,y:typ:seed;..." (výchozí startovní ostrov hry), --podzemi=0|1 (překryv podzemních těles),
#        --od=z (první vrstva), --px=N (pixelů na buňku), --bp.<param>=hodnota (parametry terénu studie),
#        --pohled=izo|shora (výchozí izo: izometrie odspodu po řez), --smer=nahoru|dolu (dolu = buňky od z po povrch).
set -euo pipefail
cd "$(dirname "$0")/.."
G=${G:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
oblast=vse; krok=2; ms=750; out=""; bloky=""; podzemi=1; od=0; px=0; pohled=izo; smer=nahoru; extra=()
for a in "$@"; do
  case "$a" in
    --oblast=*) oblast=${a#*=} ;; --krok=*) krok=${a#*=} ;; --ms=*) ms=${a#*=} ;; --out=*) out=${a#*=} ;;
    --bloky=*) bloky=${a#*=} ;; --podzemi=*) podzemi=${a#*=} ;; --od=*) od=${a#*=} ;; --px=*) px=${a#*=} ;;
    --pohled=*) pohled=${a#*=} ;; --smer=*) smer=${a#*=} ;;
    --bp.*) extra+=("$a") ;; *) echo "neznámá volba $a" >&2; exit 2 ;;
  esac
done
[ -z "$out" ] && out="shots/rez/$( [ "$oblast" = vse ] && echo ostrov || echo "blok_${oblast/,/_}" ).gif"
tmp=$(mktemp /tmp/rez_XXXX.json)
args=(--out="$tmp" --podzemi="$podzemi")
[ -n "$bloky" ] && args+=(--bloky="$bloky")
"$G" --headless --path . -s res://tools/rez_data.gd -- "${args[@]}" "${extra[@]}" 2>&1 | grep -E "rez_data|SCRIPT ERROR" || true
python3 tools/rez_gif.py "$tmp" "$out" --oblast="$oblast" --krok="$krok" --ms="$ms" --podzemi="$podzemi" --od="$od" --px="$px" --pohled="$pohled" --smer="$smer"
rm -f "$tmp"
