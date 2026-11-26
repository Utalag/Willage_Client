#!/usr/bin/env python3
"""Spočte sloupec propustnost_l_s_herni v materialy.csv z Darcyho K (1.8.1).

Vzorec (Jan t765u–t773u):
  X = Q_herni = K × 0,0625 m² × 1 × 1000   l/s herního času (při spádu 1)

Skutečný tok ve hře je X × spád (1.8.1). Tento skript počítá jen tabulkové X.
Fyzika běží v herním čase, hodnota platí přímo na herní sekundu (čistě K × A,
bez násobitele 24). Zrychlení 24× (1 herní den = 1 h) se týká jen převodu
na reálný čas: 1 herní s = 1/24 reálné s.

Hodnoty jsou přibližné. K „–“ → „–“. K s předponou „~“ zachová „~“.
Skript přepíše jen tento sloupec; ostatní pole nechá beze změny.
"""

from __future__ import annotations

import csv
import math
from pathlib import Path

PLOCHA_STENY_M2 = 0.0625
SPAD_SVISLE = 1.0
LITRU_NA_M3 = 1000.0
SLOUPEC = "propustnost_l_s_herni"
ZA_K = "K_m_s"

CSV_PATH = Path(__file__).resolve().parent / "materialy.csv"


def parse_k(raw: str) -> tuple[float | None, bool]:
    s = (raw or "").strip()
    if s in {"", "–", "-", "—"}:
        return None, False
    odhad = s.startswith("~")
    if odhad:
        s = s[1:]
    return float(s), odhad


def format_q(q: float) -> str:
    if q == 0:
        return "0"
    exp = math.floor(math.log10(abs(q)))
    if exp < -3 or exp >= 2:
        return f"{q:.2e}".replace("e+0", "e+").replace("e-0", "e-")
    return f"{q:.3g}"


def q_herni(k: float) -> float:
    return k * PLOCHA_STENY_M2 * SPAD_SVISLE * LITRU_NA_M3


def main() -> None:
    with CSV_PATH.open(newline="") as f:
        rows = list(csv.reader(f))
    if not rows:
        raise SystemExit(f"prázdný soubor: {CSV_PATH}")
    header = rows[0]
    if ZA_K not in header:
        raise SystemExit(f"chybí sloupec {ZA_K}")
    i_k = header.index(ZA_K)
    if SLOUPEC in header:
        i_q = header.index(SLOUPEC)
    else:
        i_q = i_k + 1
        header.insert(i_q, SLOUPEC)
        for row in rows[1:]:
            row.insert(i_q, "")

    n = 0
    for row in rows[1:]:
        k, odhad = parse_k(row[i_k])
        if k is None:
            row[i_q] = "–"
        else:
            val = format_q(q_herni(k))
            row[i_q] = f"~{val}" if odhad else val
            n += 1

    with CSV_PATH.open("w", newline="") as f:
        csv.writer(f, lineterminator="\n").writerows(rows)
    print(f"zapsáno {n} hodnot do {CSV_PATH.name} (sloupec {SLOUPEC})")


if __name__ == "__main__":
    main()
