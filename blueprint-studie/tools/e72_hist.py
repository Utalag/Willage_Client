#!/usr/bin/env python3
"""E72: histogram výstupů podzemí z výsledku tools/e67.gd (varianta pretok + O)."""
import json, sys
B = [0.001, 0.005, 0.02, 0.05, 0.1, 0.2, 0.5, 1e9]
for f in sys.argv[1:]:
    d = json.load(open(f))
    for v in d["varianty"]:
        if not v["varianta"].startswith("pretok"): continue
        q = [float(o[2]) for o in v["vystupy_q"]]
        h = [0] * len(B); s = [0.0] * len(B)
        for x in q:
            for i, b in enumerate(B):
                if x < b: h[i] += 1; s[i] += x; break
        lab = ["<0.001", "<0.005", "<0.02", "<0.05", "<0.1", "<0.2", "<0.5", ">=0.5"]
        print(f"{f} [{v['varianta']}] výstupů {len(q)}, Σ {sum(q):.4f} l/s, mokrá {v['mokra_pasma']}, objem {v['objem_m3']}, ms {v['ms']}")
        print("   " + "  ".join(f"{l}: {n} ({x:.3f})" for l, n, x in zip(lab, h, s)))
