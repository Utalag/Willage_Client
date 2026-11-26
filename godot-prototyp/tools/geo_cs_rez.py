#!/usr/bin/env python3
"""Krok 5: obrázek řezu švem bloků před / po opravě mince E82 (vstup: rez_*.bin z Willage.Gen.Nastroje `rez`).
Barvy hornin z data/teren/poradi_hornin.json; svislá čára = šev, oranžová křivka = síla mince 0–1 (pravá osa)."""
import json, struct, sys, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap

def nacti(p):
    b = open(p, "rb").read()
    nx, nz = struct.unpack_from("<ii", b, 0); x0, y = struct.unpack_from("<dd", b, 8); o = 24
    pov, sila, M = [], [], np.zeros((nz, nx), np.uint8)
    for i in range(nx):
        pz, s = struct.unpack_from("<dd", b, o); o += 16
        M[:, i] = np.frombuffer(b, np.uint8, nz, o); o += nz
        pov.append(pz); sila.append(s)
    return x0, y, np.array(pov), np.array(sila), M

def main(slozka, data, vystup):
    barvy = {0: "#ffffff"}
    for r in json.load(open(os.path.join(data, "teren/poradi_hornin.json")))["rocks"]:
        barvy.setdefault(int(r["id"]), r.get("color", "#888888"))
    barvy.update({75: "#3a0a0a", 7: "#7a2e1d", 57: "#9a9a9a", 47: "#e8e8ff", 21: "#2f4f2f", 38: "#e8b4b8", 42: "#4b6b3b", 8: "#b87333", 9: "#6e3b2a"})
    cmap = ListedColormap([barvy.get(i, "#cc00cc") for i in range(256)])
    fig, ax = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    for a, (jm, nadpis) in zip(ax, [("rez_puvodni.bin", "před (krok 3b): mince po blocích 128 m – skok na švu"),
                                     ("rez_opravy.bin", "po (krok 5): spojitý přechod mince 32 m")]):
        x0, y, pov, sila, M = nacti(os.path.join(slozka, jm))
        nx, nz = M.shape[1], M.shape[0]
        zlo = max(0, int((pov.min() - 40) / 0.25)); zhi = min(nz, int((pov.max() + 2) / 0.25))
        a.imshow(M[zlo:zhi], origin="lower", cmap=cmap, vmin=0, vmax=255, interpolation="nearest", aspect="auto",
                 extent=[x0, x0 + nx * 0.25, zlo * 0.25, zhi * 0.25])
        xs = x0 + nx * 0.125
        a.axvline(xs, color="k", ls="--", lw=1)
        a.set_ylabel("z (m)"); a.set_title(f"{nadpis}; řez y = {y:.0f} m, šev x = {xs:.0f} m", fontsize=10)
        a2 = a.twinx(); a2.plot(x0 + (np.arange(nx) + 0.5) * 0.25, sila, color="orange", lw=1.5); a2.set_ylim(-0.05, 1.05); a2.set_ylabel("síla mince")
    ax[1].set_xlabel("x (m)")
    fig.tight_layout(); fig.savefig(vystup, dpi=110)
    print(vystup)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
