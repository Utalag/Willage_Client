# Samostatné technické problémy

## GEO-PERIODIC-FAULT – plná periodicita a neomezené operace

**Stav: otevřeno, mimo fázi 2.** Současné nekonečné rovinné zlomy nemají vlastní periodickou definici. V0 zachovává dosavadní bezpečné vyhodnocení; nepřidává clipping bounds, nevyřazuje operace prostorovým indexem a nemění světový kontext.

GPU clipping v `Viewport3D` je pouze odříznutí zobrazovaného povrchu kvůli průřezu. Nemění geologický support, inverze, periodicitu ani materiálové výsledky. Tento pohledový clipping není řešením periodicity.

Budoucí řešení musí navrhnout skutečnou periodickou/omezenou deformaci, prokázat forward/inverse a Jacobian, změnit algorithmVersion a otestovat světové švy i historické souřadnice. Do té doby neomezené operace v navrženém indexu patří do bezpečného úplného fallbacku.