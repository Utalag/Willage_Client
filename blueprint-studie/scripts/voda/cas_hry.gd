extends RefCounted
## E77: čas hry na jednom místě (Jan 2026-11-19 22:19: 1 herní den = 1 reálná hodina, použít po testech vody).
## Simulace běží v herních sekundách (průtoky l/s, časy E51, plnění tůní, kras); reálný čas = herní / faktor.
## Faktor = parametr p71_cas (výchozí FAKTOR); kapacita dolů E71 ho používá jako převod K (m/s) na herní tok.
## Sdílené tabulky (sdilene/*_voda.json, cas_faktor, t_1m_realne_min) se přepočítají nástrojem tools/cas77.py.

const DEN_S := 86400.0
const FAKTOR := 24.0   # herních dní za reálný den (1 herní den = 60 min reálně)

static func faktor(p: Dictionary = {}) -> float:
	return float(p.get("p71_cas", p.get("cas71", FAKTOR)))

static func dny(t_s: float) -> float:
	return t_s / DEN_S

static func realne_s(t_s: float, p: Dictionary = {}) -> float:
	return t_s / faktor(p)

static func realne_min(t_s: float, p: Dictionary = {}) -> float:
	return realne_s(t_s, p) / 60.0
