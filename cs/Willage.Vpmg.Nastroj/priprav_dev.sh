#!/usr/bin/env bash
# T-1: stáhne připnutý commit Willage_Dev (jen ke čtení) do .willage-dev/<commit>/ pro nástroj Willage.Vpmg.Nastroj.
# Použití: priprav_dev.sh [--zdroj <lokální klon Willage_Dev>]
# Token (soukromé repo) jen z proměnné WILLAGE_DEV_GH_TOKEN nebo WILLAGE_CLIENT_GH_TOKEN, jen v URL příkazu fetch
# (nikdy v git configu), výstup je maskovaný.
set -euo pipefail
KOREN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PIN="$KOREN/godot-prototyp/data/vpmg/dev_pin.json"
COMMIT="$(sed -nE 's/^ *"commit": *"([0-9a-f]{40})".*/\1/p' "$PIN")"
REPO="$(sed -nE 's/^ *"repo": *"([^"]+)".*/\1/p' "$PIN")"
[ -n "$COMMIT" ] || { echo "dev_pin.json: chybí commit" >&2; exit 2; }
CIL="$KOREN/.willage-dev/$COMMIT"
maska() { sed -E 's#https://[^@]*@#https://***@#g'; }

if [ -f "$CIL/.pin-ok" ] && [ "$(git -C "$CIL" rev-parse HEAD 2>/dev/null)" = "$COMMIT" ]; then
  echo "připnutý Dev $COMMIT už je v $CIL"; exit 0
fi
rm -rf "$CIL"; mkdir -p "$CIL"; git -C "$CIL" init -q
if [ "${1:-}" = "--zdroj" ]; then
  git -C "$CIL" fetch -q --depth 1 "file://$(cd "$2" && pwd)" "$COMMIT" 2>&1 | maska
else
  TOKEN="${WILLAGE_DEV_GH_TOKEN:-${WILLAGE_CLIENT_GH_TOKEN:-}}"
  if [ -n "$TOKEN" ]; then URL="https://x-access-token:${TOKEN}@github.com/${REPO}.git"; else URL="https://github.com/${REPO}.git"; fi
  git -C "$CIL" fetch -q --depth 1 "$URL" "$COMMIT" 2>&1 | maska
fi
git -C "$CIL" -c advice.detachedHead=false checkout -q FETCH_HEAD
[ "$(git -C "$CIL" rev-parse HEAD)" = "$COMMIT" ] || { echo "HEAD ≠ pin" >&2; exit 3; }
if git -C "$CIL" config --list | grep -q x-access-token; then echo "token v git configu – mažu kopii" >&2; rm -rf "$CIL"; exit 4; fi
touch "$CIL/.pin-ok"
echo "připnutý Dev $COMMIT připraven v $CIL"
