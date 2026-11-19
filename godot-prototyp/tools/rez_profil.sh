#!/usr/bin/env bash
# Svislé řezy bloku / ostrova: 3 kolmo na X a 3 kolmo na Y v 1/4, 1/2, 3/4 + přehled 2 × 3 (bez GPU). Příklady:
#   tools/rez_profil.sh --oblast=0,0 --out=shots/rez/profil_0_0/
#   tools/rez_profil.sh                                  # celý ostrov → shots/rez/profil_ostrov/
# Volby jako tools/rez_gif.sh: --oblast=vse|x,y, --out=adresář, --bloky="x,y:typ:seed;...", --podzemi=0|1,
#   --voda=0|1 (povrchová voda + stav řešiče podzemí z ostrov_voda.gd, výchozí 1), --px=N (px na 1 m), --bp.<param>=hodnota.
set -euo pipefail
cd "$(dirname "$0")/.."
G=${G:-/workspace/tools/Godot_v4.7.2-stable_linux.x86_64}
oblast=vse; out=""; bloky=""; podzemi=1; voda=1; px=0; extra=()
for a in "$@"; do
  case "$a" in
    --oblast=*) oblast=${a#*=} ;; --out=*) out=${a#*=} ;; --bloky=*) bloky=${a#*=} ;;
    --podzemi=*) podzemi=${a#*=} ;; --voda=*) voda=${a#*=} ;; --px=*) px=${a#*=} ;;
    --bp.*) extra+=("$a") ;; *) echo "neznámá volba $a" >&2; exit 2 ;;
  esac
done
[ -z "$out" ] && out="shots/rez/profil_$( [ "$oblast" = vse ] && echo ostrov || echo "${oblast/,/_}" )/"
tmp=$(mktemp /tmp/rez_XXXX.json)
args=(--out="$tmp" --podzemi="$podzemi" --voda="$voda")
[ -n "$bloky" ] && args+=(--bloky="$bloky")
"$G" --headless --path . -s res://tools/rez_data.gd -- "${args[@]}" "${extra[@]}" 2>&1 | grep -E "rez_data|SCRIPT ERROR" || true
python3 tools/rez_profil.py "$tmp" "$out" --oblast="$oblast" --podzemi="$podzemi" --px="$px"
rm -f "$tmp"
