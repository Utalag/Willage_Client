extends RefCounted
## KOPIE z blueprint-studie/scripts/kopie/stable_hash.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Deterministické 64bitové hashe nezávislé na jazyku (C# ulong ↔ GDScript int s přetečením mod 2^64).
## - splitmix64(x): finalizér SplitMix64 (Steele, Lea, Flood 2014), vstup x + 0x9E3779B97F4A7C15
## - fnv1a64(text): FNV-1a 64 nad UTF-8 bajty
## - mix(seed, purpose, layer) = splitmix64(splitmix64(splitmix64(seed) ^ fnv1a64(purpose)) ^ layer)
##   (vlastní definice; plán backendu jmenuje StableHash64.Mix, ale bez přesného vzorce)
## - noise_seed(...) = mix(...) & 0x7FFFFFFF (FastNoiseLite bere 32bitový int seed)

const GOLDEN := -7046029254386353131   # 0x9E3779B97F4A7C15
const M1 := -4658895280553007687       # 0xBF58476D1CE4E5B9
const M2 := -7723592293110705685       # 0x94D049BB133111EB
const FNV_OFFSET := -3750763034362895579  # 0xCBF29CE484222325
const FNV_PRIME := 0x100000001B3

## logický posun vpravo (GDScript >> je aritmetický)
static func shr(x: int, k: int) -> int:
	return (x >> k) & ((1 << (64 - k)) - 1)

static func splitmix64(x: int) -> int:
	var z := x + GOLDEN
	z = (z ^ shr(z, 30)) * M1
	z = (z ^ shr(z, 27)) * M2
	return z ^ shr(z, 31)

static func fnv1a64_bytes(data: PackedByteArray, h := FNV_OFFSET) -> int:
	for b in data:
		h = (h ^ b) * FNV_PRIME
	return h

static func fnv1a64(text: String) -> int:
	return fnv1a64_bytes(text.to_utf8_buffer())

static func mix(seed: int, purpose: String, layer: int) -> int:
	return splitmix64(splitmix64(splitmix64(seed) ^ fnv1a64(purpose)) ^ layer)

static func noise_seed(seed: int, purpose: String, layer: int) -> int:
	return mix(seed, purpose, layer) & 0x7FFFFFFF

## pojmenovaný seed unikátního bloku: FNV-1a 64 jména, horní bit vynulován (kladné číslo)
static func named_seed(name: String) -> int:
	return fnv1a64(name) & 0x7FFFFFFFFFFFFFFF

static func hex(h: int) -> String:
	return "%08x%08x" % [shr(h, 32), h & 0xFFFFFFFF]
