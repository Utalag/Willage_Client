"""Svislý řez pouštním pobřežím (krok 7 / 7b). Vstup: bin+csv z `eroze rez --planeta poust`."""
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

def kresli(bin_cesta, csv_cesta, vystup, titulek, dpi=90):
    n, nz, krok, P, W, K, M = nacti_bin(bin_cesta)
    c = nacti_csv(csv_cesta)
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
    zmin = max(20, np.floor(min(P.min(), np.nanmin(W)) - 10))
    zmax = np.ceil(max(P.max(), 62) + 6)
    fig, a = plt.subplots(figsize=(16, 7.2))
    a.imshow(Mi, origin='lower', extent=[0, n * krok, 0, nz * krok], cmap=cm, norm=nm, aspect='auto', interpolation='nearest')
    a.fill_between(s, np.minimum(P, 60), 60, where=je == 1, color='#3070ff', alpha=0.45, label='moře (hladina 60 m)')
    a.plot(s, P, 'k', lw=1.3, label='povrch')
    a.axhline(60, color='#0030c0', ls='--', lw=0.8, label='60 m (reference)')
    a.plot(s, Wk, color='#00b0ff', lw=1.9, label='hladina podzemní vody (na pevnině; u břehu napojení 5 m)')
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
    l1 = a.legend(loc='upper left', fontsize=8, framealpha=0.92)
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
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'shots/rez-poust'
    src = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('/tmp/rez-poust')
    kresli(src / 'rez_200.bin', src / 'rez_200.csv', out / 'rez_poust_200m.png',
           'Řez 200 m, buňka 0,25 m: pouštní planeta, seed 49, subtropické pásmo.\n'
           'Od x 13848 y 14368 m směrem +x (1, 0). Moře vlevo, suchá poušť vpravo. Žádný pramen ani oáza na řezu.')
    kresli(src / 'rez_1000.bin', src / 'rez_1000.csv', out / 'rez_poust_1000m.png',
           'Řez 1000 m (přehled), buňka 0,25 m: stejná úsečka jako řez 200 m, pokračuje do vnitrozemí.\n'
           'Oranžový pruh = suché koryto (pozůstatek eroze, bez dnešního průtoku). Oáza na řezu není (nejbližší ~475 m stranou).')
