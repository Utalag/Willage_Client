import { hashInt3, hashToSigned } from "./hash";

const fade = (t: number) => t * t * t * (t * (t * 6 - 15) + 10);
const wrap = (i: number, period: number) => {
  if (period <= 0) return i;
  const m = i % period;
  return m < 0 ? m + period : m;
};

/**
 * 2D value noise in [-1, 1]. Lattice values are hashes of integer corners, interpolated
 * with the quintic fade 6t^5-15t^4+10t^3 (C2 continuous).
 * periodX/periodY > 0 (in lattice cells) make the noise periodic → toroidal worlds.
 */
export function valueNoise2(x: number, y: number, seed: number, periodX = 0, periodY = 0): number {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const tx = fade(x - xi);
  const ty = fade(y - yi);
  const x0 = wrap(xi, periodX), x1 = wrap(xi + 1, periodX);
  const y0 = wrap(yi, periodY), y1 = wrap(yi + 1, periodY);
  const a = hashToSigned(hashInt3(x0, y0, 0, seed));
  const b = hashToSigned(hashInt3(x1, y0, 0, seed));
  const c = hashToSigned(hashInt3(x0, y1, 0, seed));
  const d = hashToSigned(hashInt3(x1, y1, 0, seed));
  const ab = a + (b - a) * tx;
  const cd = c + (d - c) * tx;
  return ab + (cd - ab) * ty;
}

/**
 * Fractal sum of value noise, normalised to [-1, 1].
 * frequency in cycles per metre. worldPeriodX/Y in metres (0 = not periodic);
 * periodic axes snap the frequency to round(P·f)/P, so the result is exactly periodic
 * (x and x+P hit the same wrapped lattice corners).
 */
export function fbm2(
  x: number,
  y: number,
  seed: number,
  frequency: number,
  octaves: number,
  worldPeriodX = 0,
  worldPeriodY = 0,
): number {
  // On periodic axes the frequency is snapped so that worldPeriod·f is an integer ≥ 1.
  let fx = worldPeriodX > 0 ? Math.max(1, Math.round(worldPeriodX * frequency)) / worldPeriodX : frequency;
  let fy = worldPeriodY > 0 ? Math.max(1, Math.round(worldPeriodY * frequency)) / worldPeriodY : frequency;
  let sum = 0, amp = 1, norm = 0;
  for (let o = 0; o < octaves; o++) {
    const px = worldPeriodX > 0 ? Math.round(worldPeriodX * fx) : 0;
    const py = worldPeriodY > 0 ? Math.round(worldPeriodY * fy) : 0;
    sum += amp * valueNoise2(x * fx, y * fy, (seed + o * 1013) | 0, px, py);
    norm += amp;
    amp *= 0.5;
    fx *= 2;
    fy *= 2;
  }
  return sum / norm;
}
