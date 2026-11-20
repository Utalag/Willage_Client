#!/usr/bin/env python3
"""E83: audit determinismu herního kódu prototypu (generátor, překryv, voda). Počítá místa, která mohou dát jiné bity
na jiné platformě (ARM / telefon / C# server) nebo závisí na pořadí či čase. Výstup: markdown na stdout."""
import os, re, sys
ROOT = os.path.join(os.path.dirname(__file__), "..", "scripts")
DIRS = ["teren", "voda", "block_gen.gd", "block.gd"]
SKIP = ("studie_testy", "demo", "gen3", "svet64")
PAT = {
    "exp/log/pow": r"\b(exp|log|pow)\(",
    "sin/cos/tan/atan": r"\b(sin|cos|tan|atan2?|asin|acos)\(",
    "sqrt": r"\bsqrt\(|\.length\(\)|distance_to\(",
    "šum FastNoiseLite": r"get_noise_[123]d|\bnoise\(",
    "sort_custom": r"sort_custom\(",
    "iterace slovníku bez sort": None,
    "float ve formátu (klíč/hash)": r'"[^"]*%\.\d+f[^"]*"\s*%',
    "hash() Godotu": r"\.hash\(\)|\bhash\(",
    "RandomNumberGenerator/randi": r"RandomNumberGenerator|\brandi\(|\brandf\(|randomize\(",
    "čas (Time/OS)": r"Time\.get_|OS\.get_ticks",
}
def files():
    for d in DIRS:
        p = os.path.join(ROOT, d)
        if os.path.isfile(p): yield p; continue
        for dp, _, fs in os.walk(p):
            if any(s in dp for s in SKIP): continue
            for f in fs:
                if f.endswith(".gd"): yield os.path.join(dp, f)
rows = []; tot = {k: 0 for k in PAT}
for f in sorted(files()):
    src = open(f, encoding="utf-8").read().split("\n")
    cnt = {k: 0 for k in PAT}
    for i, line in enumerate(src):
        code = line.split("#", 1)[0]
        for k, rx in PAT.items():
            if rx and re.search(rx, code): cnt[k] += len(re.findall(rx, code))
        m = re.search(r"for \w+ in ([\w\.]+)(\.keys\(\))?\s*:", code)
        if m and m.group(2):
            prev = "\n".join(src[max(0, i - 2):i])
            if ".sort()" not in prev: cnt["iterace slovníku bez sort"] += 1
    if any(cnt.values()):
        rows.append((os.path.relpath(f, ROOT), cnt))
        for k in cnt: tot[k] += cnt[k]
print("| soubor | " + " | ".join(PAT) + " |")
print("|---|" + "---|" * len(PAT))
for f, c in rows: print(f"| {f} | " + " | ".join(str(c[k]) for k in PAT) + " |")
print("| **celkem** | " + " | ".join(f"**{tot[k]}**" for k in PAT) + " |")
