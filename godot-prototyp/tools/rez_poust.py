"""Svislý řez (krok 7 / 7b / 7c). Vstup: bin + csv + mat.csv z `eroze rez` (volitelně --planeta poust).
Šrafa = zvodnělé buňky (pod hladinou podzemní vody, kde existuje, a propustný materiál); těsnění bez šrafy; chybí-li hladina, čára se nekreslí."""
import struct, json, sys
from pathlib import Path
import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm
import csv

ROOT = Path(__file__).resolve().parents[1]
KAT = json.load(open(ROOT / 'data/v1/materials-catalog-v1.json'))
KRATKE = {
    2: 'ornice', 3: 'štěrk / písek', 4: 'zvětralá břidlice', 5: 'jeskynní vápenec',
    6: 'žula', 7: 'diabaz', 8: 'měď', 20: 'peridotit', 21: 'kimberlit',
    26: 'gabro', 28: 'magnetit', 30: 'amfibolit', 33: 'ortorula', 36: 'granodiorit',
    38: 'pegmatit', 40: 'svor', 42: 'skarn', 44: 'hlubinný vápenec', 47: 'kamenná sůl',
    49: 'dolomit', 51: 'jílová břidlice', 52: 'křemenný pískovec', 54: 'spraš',
}
def nazev(i):
    if i in KRATKE: return KRATKE[i]
    n = next((m['name'] for m in KAT['materials'] if m['id'] == i), f'id {i}')
    return n.split('(=')[0].split('(')[0].strip().rstrip(',')

BIOM = {0: 'moře', 5: 'step', 6: 'poušť', 7: 'savana', 10: 'oáza'}

def nacti_bin(f):
    b = open(f, 'rb').read()
    n, nz = struct.unpack('ii', b[:8])
    krok = struct.unpack('d', b[8:16])[0]; o = 16
    P, W, K = [], [], []
    M = np.zeros((nz, n), np.uint8)
    for i in range(n):
        p, w, k = struct.unpack('ddd', b[o:o + 24]); o += 24
        M[:, i] = np.frombuffer(b, np.uint8, nz, o); o += nz
        P.append(p); W.append(w); K.append(k)
    return n, nz, krok, np.array(P), np.array(W), np.array(K), M

def nacti_csv(f):
    rows = list(csv.DictReader(open(f)))
    return {k: np.array([float(r[k]) for r in rows]) for k in rows[0]}

def nacti_teleso(f):
    t = {}
    for r in csv.DictReader(open(f)):
        t[int(r['id'])] = int(r['teleso'])
    return t

def kresli(bin_cesta, csv_cesta, vystup, titulek, dpi=90, mat_cesta=None):
    n, nz, krok, P, W, K, M = nacti_bin(bin_cesta)
    c = nacti_csv(csv_cesta)
    tel = nacti_teleso(mat_cesta or str(csv_cesta).replace('.csv', '.mat.csv'))
    s, je, hydro, er, biom = c['s'], c['jemore'], c['hydro'].astype(int), c['eroze_m'], c['biom'].astype(int)
    ids = sorted(set(np.unique(M)) - {0})
    lut = np.zeros(256, int)
    for t, i in enumerate(ids):
        lut[i] = t + 1
    Mi = lut[M]
    cols = ['#ffffff'] + [plt.cm.tab20(t % 20) for t in range(len(ids))]
    cm = ListedColormap(cols)
    nm = BoundaryNorm(np.arange(-0.5, len(ids) + 1.5), cm.N)
    Wk = np.where(je == 1, np.nan, W)
    zmin = max(20, np.floor(min(P.min(), np.nanmin(W) if np.any(~np.isnan(W)) else P.min()) - 10))
    zmax = np.ceil(max(P.max(), 62) + 6)
    fig, a = plt.subplots(figsize=(16, 7.2))
    a.imshow(Mi, origin='lower', extent=[0, n * krok, 0, nz * krok], cmap=cm, norm=nm, aspect='auto', interpolation='nearest')
    # zvodnělá zóna: buňka pod hladinou (kde existuje) a pod povrchem, propustný materiál (těleso)
    zc = (np.arange(nz) + 0.5) * krok
    nas = (zc[:, None] < np.where(np.isnan(W), -1e9, W)[None, :]) & (zc[:, None] < P[None, :]) & (M > 0)
    teleso = np.zeros(256, bool)
    for i, v in tel.items(): teleso[i] = v == 1
    nas &= teleso[M]
    xs = (np.arange(n) + 0.5) * krok
    plt.rcParams['hatch.linewidth'] = 0.6
    plt.rcParams['hatch.color'] = '#0b3d91'
    a.contourf(xs, zc, nas.astype(float), levels=[0.5, 1.5], colors='none', hatches=['////'])
    a.fill_between(s, np.minimum(P, 60), 60, where=je == 1, color='#3070ff', alpha=0.45, label='moře (hladina 60 m)')
    a.plot(s, P, 'k', lw=1.3, label='povrch')
    a.axhline(60, color='#0030c0', ls='--', lw=0.8, label='60 m (reference)')
    a.plot(s, Wk, color='#00b0ff', lw=1.9, label='hladina podzemní vody (na pevnině; u břehu napojení 5 m)')
    bez = (je == 0) & np.isnan(W)
    if np.any(bez):
        a.fill_between(s, zmax - 1.2, zmax, where=bez, color='#c0392b', alpha=0.6, label='bez hladiny podzemní vody (není dobíjená)')
    if np.any(je == 0):
        sb = s[np.argmax(je == 0)]
        a.axvline(sb, color='#008000', lw=1.0, ls='--', label='břeh (konec moře)')
        a.axvline(sb + 5, color='#008000', lw=0.8, ls=':', label='5 m od břehu')
    # suchá / aktivní koryta (příznak z hrubé mapy 32 m)
    dry = (hydro & 2) != 0
    akt = (hydro & 1) != 0
    if np.any(dry):
        a.fill_between(s, zmin, zmax, where=dry, color='#e67e22', alpha=0.18, label='suché koryto (pozůstatek eroze)')
    if np.any(akt):
        a.fill_between(s, zmin, zmax, where=akt, color='#2e86de', alpha=0.18, label='aktivní koryto')
    oaza = biom == 10
    if np.any(oaza):
        a.fill_between(s, zmin, zmax, where=oaza, color='#ff2d95', alpha=0.22, label='biom oáza')
    a.set_ylim(zmin, zmax)
    a.set_xlim(0, n * krok)
    a.set_xlabel('vzdálenost podél řezu (m), moře vlevo → poušť vpravo')
    a.set_ylabel('výška z (m)')
    a.set_title(titulek, fontsize=11)
    from matplotlib.patches import Patch
    hl, ll = a.get_legend_handles_labels()
    hl.append(Patch(facecolor='white', edgecolor='#0b3d91', hatch='////', label='zvodnělé buňky: pod hladinou a propustný materiál (K ≥ práh nebo rozpustná hornina: vápenec, dolomit, sůl); těsnění bez šrafy'))
    l1 = a.legend(hl, ll + [hl[-1].get_label()], loc='upper left', fontsize=8, framealpha=0.92)
    a.add_artist(l1)
    h = [plt.Rectangle((0, 0), 1, 1, color=cols[t + 1]) for t in range(len(ids))]
    a.legend(h, [f'{i}  {nazev(i)}' for i in ids], loc='lower right', fontsize=7.5, ncol=2, title='materiál', framealpha=0.92)
    plt.tight_layout()
    vystup = Path(vystup)
    vystup.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(vystup, dpi=dpi)
    plt.close()
    print('zapsáno', vystup)

if __name__ == '__main__':
    # použití: rez_poust.py <vystupni_slozka> <zdroj_slozka>  (zdroj: poust_200, poust_1000, mirne_100 jako .bin/.csv/.mat.csv)
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'shots/krok07c'
    src = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('/workspace/k07c/r')
    sada = [
        ('poust_200', 'rez_poust_200m.png', 'Pouštní pobřeží, řez 200 m (planeta poušť, seed 49, subtropické pásmo): buňka 0,25 m, od x 13848 y 14368 m směrem +x. Moře vlevo.'),
        ('poust_1000', 'rez_poust_1000m.png', 'Pouštní pobřeží, přehled 1 km (stejná úsečka): hladina podzemní vody končí tam, kde není dobíjená; suché koryto oranžově.'),
        ('mirne_100', 'rez_mirne_strme_100m.png', 'Strmé pobřeží mírné planety (seed 49, řez kroku 6g): od x 22489,4 y 5322,3 m, směr (0,97; −0,26), buňka 0,25 m.'),
    ]
    for jm, png, tit in sada:
        if (src / f'{jm}.bin').exists():
            kresli(src / f'{jm}.bin', src / f'{jm}.csv', out / png, tit)
