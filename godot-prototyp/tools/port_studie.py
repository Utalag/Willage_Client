#!/usr/bin/env python3
"""E66: přenos modulů terénu a vody z ../blueprint-studie/scripts do prototypu (kopie beze změny logiky).

Mění se jen cesty: res://scripts/<složka studie>/x.gd -> res://scripts/<cíl>/x.gd, res://data/ -> res://data/teren/,
res://shots/ -> res://shots/66_parita/ (výstupy testů parity). Na začátek se přidá řádek s původem kopie.
Kořeny = moduly, které hra a test parity potřebují; zbytek se dohledá přes preload/load (tranzitivně).
Logika se nemění (PATCHES je prázdné).
Použití: python3 tools/port_studie.py [--check]   (--check jen porovná, nic nepíše; návratový kód 1 = rozdíl)
"""
import hashlib, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROTO = os.path.dirname(HERE)
STUDY = os.path.normpath(os.path.join(PROTO, "..", "blueprint-studie"))

ROOTS = [
    # terén: funkce vrstev, navázání, minerály, dutiny
    "bp/pipeline.gd", "bp/geo_fn.gd", "bp/params.gd", "bp/world.gd", "bp/blueprint.gd",
    # voda: prameny, koryto, strže, tůně, podzemí auto, E58/E60/E64, eroze E51, dohnání E54
    "voda/prameny.gd", "voda/strze.gd", "voda/tok.gd", "alg60/tok60.gd", "podzemi52/ug_funkce.gd", "hydro68/hydro68.gd", "kras75/kras75.gd",
    "alg58/ug58.gd", "alg58/rec58.gd", "alg64/ug64.gd", "alg64/sestup64.gd", "alg64/pre64.gd", "alg64/heap64.gd",
    "eroze51/mech.gd", "eroze51/hydro.gd", "eroze51/halda.gd", "svet64/voda64.gd", "podzemi52/cache.gd",
    # test parity (stejné testy jako ve studii)
    "bp/tests.gd", "bp/tests_horniny.gd", "svet8/beh.gd", "voda/tests_voda.gd", "voda/tests_voda_b.gd", "dohnani54/beh54.gd",
]
# testovací moduly jdou zvlášť (do hry se nenačítají)
TEST_ONLY = {"bp/tests.gd", "bp/tests_horniny.gd", "bp/naive.gd", "bp/metrics.gd", "bp/scenario_data.gd", "bp/scenario_horniny.gd",
             "svet8/beh.gd", "voda/tests_voda.gd", "voda/tests_voda_b.gd", "voda/tests_podzemi.gd", "voda/tests_tun.gd",
             "dohnani54/beh54.gd", "eroze51/beh51.gd", "eroze51/scenare.gd", "podzemi52/testy52.gd", "podzemi52/beh52.gd"}
DIRMAP = {"bp": "teren", "kopie": "teren/zaklad", "svet8": "teren/svet", "svah56": "teren/svet", "svet64": "teren/svet64",
          "voda": "voda", "alg60": "voda/povrch", "alg58": "voda/podzemi", "alg64": "voda/podzemi", "podzemi52": "voda/podzemi",
          "eroze51": "voda/eroze", "dohnani54": "voda/eroze", "hydro68": "voda", "kras75": "voda/podzemi"}
TEST_DIR = "studie_testy"
RX = re.compile(r'res://scripts/([a-z0-9_]+)/([A-Za-z0-9_]+\.gd)')

# opt-in změny (výchozí hodnota = chování studie); (soubor studie, hledaný text, náhrada)
PATCHES = [
    # E66: původně opt-in edge_wall v tok._border; nahrazeno příkopem mlhy v adaptéru (scripts/voda/ostrov_voda.gd),
    # takže kopie jsou bez jediné změny logiky. Seznam zůstává pro případné opt-in úpravy.
]

# nástroje studie pro test parity E64 (čtou záznam volání a cache světa přímo ze studie, píšou do shots/66_parita/)
TOOL_PORTS = [("tools/alg64_ug.gd", "tools/studie_alg64_ug.gd",
               [('"res://shots/alg58/', '"res://../blueprint-studie/shots/alg58/'), ('"res://shots/e64/', '"res://shots/66_parita/')])]

def dest(rel):
    d, f = rel.split("/")
    if rel in TEST_ONLY:
        return f"{TEST_DIR}/{f}"
    return f"{DIRMAP[d]}/{f}"

def deps(rel):
    src = open(os.path.join(STUDY, "scripts", rel), encoding="utf-8").read()
    return sorted({f"{a}/{b}" for a, b in RX.findall(src)})

def closure():
    seen, todo = set(), list(ROOTS)
    while todo:
        r = todo.pop()
        if r in seen: continue
        if r.split("/")[0] not in DIRMAP:
            raise SystemExit(f"neznámá složka studie: {r}")
        seen.add(r)
        todo += deps(r)
    return sorted(seen)

def convert(rel):
    src = open(os.path.join(STUDY, "scripts", rel), encoding="utf-8").read()
    for f, a, b in PATCHES:
        if f == rel:
            assert a in src, f"patch nesedí: {rel}"
            src = src.replace(a, b, 1)
    src = RX.sub(lambda m: "res://scripts/" + dest(f"{m.group(1)}/{m.group(2)}"), src)
    src = src.replace('"res://data/', '"res://data/teren/').replace('res://shots/', 'res://shots/66_parita/')
    lines = src.split("\n")
    note = f"## KOPIE z blueprint-studie/scripts/{rel} (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy" + \
           ("; patch: opt-in edge_wall" if any(p[0] == rel for p in PATCHES) else "") + "."
    lines.insert(1, note)
    return "\n".join(lines)

def main():
    check = "--check" in sys.argv
    files = closure()
    out = {}
    for rel in files:
        out["scripts/" + dest(rel)] = convert(rel)
    for src_t, dst_t, reps in TOOL_PORTS:
        t = open(os.path.join(STUDY, src_t), encoding="utf-8").read()
        for a, b in reps: t = t.replace(a, b)
        t = RX.sub(lambda m: "res://scripts/" + dest(f"{m.group(1)}/{m.group(2)}"), t)
        tl = t.split("\n"); tl.insert(1, f"## KOPIE z blueprint-studie/{src_t} (E66, tools/port_studie.py): změněné jen cesty."); out[dst_t] = "\n".join(tl)
    for d in ["mineraly_hostitele.json", "poradi_hornin.json"]:
        out["data/teren/" + d] = open(os.path.join(STUDY, "data", d), encoding="utf-8").read()
    names = {}
    for k in out:
        b = os.path.basename(k)
        if k.endswith(".gd") and os.path.dirname(k) in names.get(b, []):
            raise SystemExit("kolize " + k)
        names.setdefault(b, []).append(os.path.dirname(k))
    diff = 0
    manifest = {}
    for k, v in sorted(out.items()):
        p = os.path.join(PROTO, k)
        old = open(p, encoding="utf-8").read() if os.path.exists(p) else None
        manifest[k] = hashlib.sha256(v.encode()).hexdigest()[:16]
        if old != v:
            diff += 1
            if check: print("rozdíl:", k)
            else:
                os.makedirs(os.path.dirname(p), exist_ok=True)
                open(p, "w", encoding="utf-8").write(v)
    src_map = {("scripts/" + dest(r)): ("blueprint-studie/scripts/" + r) for r in files}
    if not check:
        json.dump({"popis": "E66 přenos modulů ze studie (tools/port_studie.py)", "soubory": src_map, "sha256_16": manifest},
                  open(os.path.join(PROTO, "data", "teren", "port_manifest.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"souborů {len(out)} ({len(files)} skriptů), změněno {diff}")
    sys.exit(1 if (check and diff) else 0)

if __name__ == "__main__":
    main()
