/**
 * Stateless integer hashing. All randomness in the engine is a pure function of
 * (integer lattice coordinates, seed) – there is no global RNG, so the order in
 * which points are evaluated can never change a result.
 * Only 32-bit integer ops (Math.imul, xor, shifts) are used: bit-identical on every JS engine.
 */
export function hashInt3(x: number, y: number, z: number, seed: number): number {
  let h = Math.imul(seed | 0, 0x27d4eb2d) ^ 0x165667b1;
  h = Math.imul(h ^ (x | 0), 0xcc9e2d51);
  h = (h << 15) | (h >>> 17);
  h = Math.imul(h ^ (y | 0), 0x1b873593);
  h = (h << 13) | (h >>> 19);
  h = Math.imul(h ^ (z | 0), 0xe6546b64);
  h ^= h >>> 16;
  h = Math.imul(h, 0x85ebca6b);
  h ^= h >>> 13;
  h = Math.imul(h, 0xc2b2ae35);
  h ^= h >>> 16;
  return h >>> 0;
}

/** Uniform value in [-1, 1) from a uint32 hash. */
export const hashToSigned = (h: number) => h / 2147483648 - 1;

/** Derive an independent sub-seed (e.g. one per sediment layer) from an event seed. */
export const deriveSeed = (seed: number, salt: number) => hashInt3(salt, 0x5eed, 0x1234, seed);

/** FNV-1a 32-bit hash of a string (used to derive default event seeds from stable IDs). */
export function hashString(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}
